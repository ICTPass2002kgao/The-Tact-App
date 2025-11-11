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
import 'package:path_provider/path_provider.dart'; // Used only for non-web environments
import 'dart:io'; // Standard dart:io, will fail on web unless excluded, but we use kIsWeb for logic branch

// Assuming these are local files you already have
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

// --- Paystack API Imports ---
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
// ----------------------------

// --- PLATFORM AND LAYOUT UTILITIES ---
bool get _useCupertinoStyle =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
const double _tabletBreakpoint = 768.0;
const double _desktopContentMaxWidth = 1200.0;
// ------------------------------------

class OverseerPage extends StatefulWidget {
  const OverseerPage({super.key});

  @override
  State<OverseerPage> createState() => _OverseerPageState();
}

class _OverseerPageState extends State<OverseerPage>
    with SingleTickerProviderStateMixin {
  // Tabs: Dashboard, Add Member, All Members, Reports (Length: 4)
  late TabController _tabController;

  Uint8List? _logoBytes;

  // --- PAYSTACK/SUBSCRIPTION STATE & CONSTANTS ---
  static const String cloudFunctionBaseUrl =
      'https://us-central1-PROJECT_ID.cloudfunctions.net/api'; // <--- UPDATE THIS

  static const int tier1AmountCents = 18900; // R189.00 (50+ members)
  static const int tier2AmountCents = 25000; // R250.00 (300+ members)
  static const int tier3AmountCents = 29900; // R299.00 (500+ members)

  bool _isSubscriptionActive = false;
  // ---------------------------------------------------

  // --- TEXT CONTROLLERS & STATE FOR MEMBER/REPORTS ---
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController memberNameController = TextEditingController();
  final TextEditingController memberEmailController = TextEditingController();
  final TextEditingController memberAddressController = TextEditingController();
  final TextEditingController memberContactController = TextEditingController();
  final TextEditingController memberSurnameController = TextEditingController();
  final TextEditingController week1Controller = TextEditingController();
  final TextEditingController week2Controller = TextEditingController();
  final TextEditingController week3Controller = TextEditingController();
  final TextEditingController week4Controller = TextEditingController();
  final TextEditingController officerNameController = TextEditingController();
  final TextEditingController communityOfficerController =
      TextEditingController();
  double week1 = 0.0;
  double week2 = 0.0;
  double week3 = 0.0;
  double week4 = 0.0;
  String? selectedDistrictElder;
  String? selectedCommunityName;
  String selectedProvince = '';
  // --------------------------------------------------

  // --- CHART DATA STATE ---
  // Bar Chart (Existing)
  List<BarChartGroupData> _monthlyOfferingsData = [];
  Map<String, double> _districtTotals = {};
  double _maxOfferingAmount = 0.0;

  // Pie Chart (NEW)
  Map<String, int> _districtMemberCounts = {};
  int _totalMemberCountForChart = 0;

  // Line Chart (NEW)
  Map<int, double> _weeklyTotals = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
  double _maxWeeklyTithe = 0.0;
  // -------------------------

  // Define chart colors
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
    // Updated length to 4 (Dashboard, Add Member, All Members, Reports)
    _tabController = TabController(length: 5, vsync: this);
    _loadLogoBytes();
    _checkSubscriptionStatusFromFirestore();
    _loadDashboardData(); // Renamed function

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          // Trigger rebuild for search filter on 'All Members' tab
        });
      }
    });
  }

  // --- NEW: Chart Data Fetching Logic ---
  Future<void> _loadDashboardData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('overseerUid', isEqualTo: uid)
          .get();

      // --- Initialize temporary aggregates ---
      Map<String, double> districtTitheTotals = {};
      Map<String, int> districtMemberCounts = {};
      Map<int, double> weeklyTitheTotals = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
      double maxTitheTotal = 0.0;
      double maxWeekly = 0.0;
      int totalMembers = 0;

      // --- Loop through all members once ---
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalMembers++;

        final districtName =
            data['districtElderName'] as String? ?? 'Unassigned District';

        final w1 = (data['week1'] as num? ?? 0.0).toDouble();
        final w2 = (data['week2'] as num? ?? 0.0).toDouble();
        final w3 = (data['week3'] as num? ?? 0.0).toDouble();
        final w4 = (data['week4'] as num? ?? 0.0).toDouble();
        final monthlyTotal = w1 + w2 + w3 + w4;

        // 1. Aggregate for Bar Chart (Tithe by District)
        districtTitheTotals.update(
          districtName,
          (value) => value + monthlyTotal,
          ifAbsent: () => monthlyTotal,
        );

        // 2. Aggregate for Pie Chart (Members by District)
        districtMemberCounts.update(
          districtName,
          (value) => value + 1,
          ifAbsent: () => 1,
        );

        // 3. Aggregate for Line Chart (Tithe by Week - All Districts)
        weeklyTitheTotals[1] = (weeklyTitheTotals[1] ?? 0) + w1;
        weeklyTitheTotals[2] = (weeklyTitheTotals[2] ?? 0) + w2;
        weeklyTitheTotals[3] = (weeklyTitheTotals[3] ?? 0) + w3;
        weeklyTitheTotals[4] = (weeklyTitheTotals[4] ?? 0) + w4;
      }

      // --- Prepare Bar Chart Data ---
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
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
            showingTooltipIndicators: [0],
          ),
        );
        maxTitheTotal = maxTitheTotal > total ? maxTitheTotal : total;
        index++;
      });

      // --- Find max for Line Chart Y-axis ---
      maxWeekly = weeklyTitheTotals.values.reduce(
        (max, v) => max > v ? max : v,
      );

      // --- Set state for all charts ---
      if (mounted) {
        setState(() {
          // Bar Chart
          _monthlyOfferingsData = chartGroups;
          _districtTotals = districtTitheTotals;
          _maxOfferingAmount = maxTitheTotal > 0
              ? maxTitheTotal * 1.2
              : 100.0; // Ensure min value if data is 0

          // Pie Chart
          _districtMemberCounts = districtMemberCounts;
          _totalMemberCountForChart = totalMembers;

          // Line Chart
          _weeklyTotals = weeklyTitheTotals;
          _maxWeeklyTithe = maxWeekly > 0 ? maxWeekly * 1.2 : 100.0;
        });
      }
    } catch (e) {
      print("Error loading dashboard data: $e");
    }
  }

  // --- PAYSTACK/SUBSCRIPTION LOGIC (Kept as is) ---

  Future<void> _checkSubscriptionStatusFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isSubscriptionActive = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('overseers')
          .doc(uid)
          .get();

      if (mounted) {
        setState(() {
          _isSubscriptionActive =
              doc.exists && doc.data()?['subscriptionStatus'] == 'active';
        });
      }
    } catch (e) {
      print("Firestore Subscription Check Error: $e");
      if (mounted) setState(() => _isSubscriptionActive = false);
    }
  }

  Future<int> _getTotalOverseerMemberCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('overseerUid', isEqualTo: uid)
        .get();
    return snapshot.docs.length;
  }

  int _determineSubscriptionAmount(int memberCount) {
    if (memberCount >= 500) {
      return tier3AmountCents;
    } else if (memberCount >= 300) {
      return tier2AmountCents;
    } else if (memberCount >= 50) {
      return tier1AmountCents;
    } else {
      return tier1AmountCents;
    }
  }

  Future<void> _initiatePaystackSubscription(
    int memberCount,
    BuildContext context,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      Api().showMessage(
        context,
        'Please log in to subscribe.',
        'Error',
        Theme.of(context).primaryColorDark,
      );
      return;
    }

    final amountCents = _determineSubscriptionAmount(memberCount);
    final tierName = memberCount >= 500
        ? 'Tier 3 (500+)'
        : (memberCount >= 300 ? 'Tier 2 (300-499)' : 'Tier 1 (50+)');

    Api().showLoading(context);
    try {
      final response = await http.post(
        Uri.parse('$cloudFunctionBaseUrl/initialize-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': user.email,
          'amount': amountCents,
          'uid': user.uid,
          'tier': tierName,
          'memberCount': memberCount,
        }),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final authUrl = data['authorization_url'] as String?;

        if (authUrl != null) {
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Complete Subscription'),
              content: Text(
                'Please proceed to the Paystack page to authorize your card for automatic monthly payments based on the $tierName plan (R${(amountCents / 100).toStringAsFixed(2)}).',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Open Payment Page'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await launchUrl(Uri.parse(authUrl));
                    Api().showMessage(
                      context,
                      'Launching Paystack for authorization...',
                      'Info',
                      Theme.of(context).primaryColor,
                    );
                    print('Launching Paystack URL: $authUrl');
                  },
                ),
              ],
            ),
          );
        } else {
          Api().showMessage(
            context,
            'Failed to get payment URL.',
            'Error',
            Theme.of(context).primaryColorDark,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        Api().showMessage(
          context,
          errorData['error'] ?? 'Subscription initialization failed.',
          'Error',
          Theme.of(context).primaryColorDark,
        );
      }
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        'An error occurred during subscription setup: $e',
        'Error',
        Theme.of(context).primaryColorDark,
      );
    }
  }

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

  // --- Custom Platform/Web-Friendly Widgets ---

  Widget _platformTextField({
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    final ThemeData color = Theme.of(context);
    if (_useCupertinoStyle) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: color.primaryColor.withOpacity(0.5)),
            color: color.scaffoldBackgroundColor,
          ),
          padding: const EdgeInsets.all(12.0),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: placeholder,
            labelStyle: TextStyle(fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            fillColor: color.scaffoldBackgroundColor,
            filled: true,
            contentPadding: EdgeInsets.all(12.0),
          ),
        ),
      );
    }
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required Future<int> Function() countFuture,
    required IconData icon,
    Color? backgroundColor,
  }) {
    final color = Theme.of(context);
    final cardColor = backgroundColor ?? color.primaryColor.withOpacity(0.8);

    return FutureBuilder<int>(
      future: countFuture(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 4,
            child: Shimmer.fromColors(
              baseColor: color.hintColor.withOpacity(0.3),
              highlightColor: color.hintColor.withOpacity(0.1),
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: color.scaffoldBackgroundColor,
                ),
              ),
            ),
          );
        }
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(18.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color.scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                    Icon(icon, color: color.scaffoldBackgroundColor, size: 40),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  '${count}',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Bar Chart Widget for Dashboard (Existing) ---
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

  // --- NEW: Pie Chart for Member Distribution ---
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

  // --- NEW: Line Chart for Weekly Tithe Trend ---
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

  // --- Reusable Chart Placeholder ---
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
      print("Fetched districts: $districts");
      return districts?.length ?? 0;
    } catch (e) {
      print("Error fetching district count: $e");
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
      print("Fetched branches: $totalBranches");
      return totalBranches;
    } catch (e) {
      print("Error fetching branch count: $e");
      return 0;
    }
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isWiderScreen =
        MediaQuery.of(context).size.width >= _tabletBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overseer Dashboard'),
        centerTitle: true,
        foregroundColor: color.scaffoldBackgroundColor,
        backgroundColor: color.primaryColor,
      ),
      backgroundColor: color.scaffoldBackgroundColor,
      drawer: Drawer(
        backgroundColor: color.primaryColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: color.primaryColor),
              child: Text(
                'Overseer Menu',
                style: TextStyle(
                  color: color.scaffoldBackgroundColor,
                  fontSize: 24,
                ),
              ),
            ),
            // Navigation items corresponding to the 4 tabs
            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text('Dashboard'),
              onTap: () {
                _tabController.index = 0;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_add),
              title: Text('Add Member'),
              onTap: () {
                _tabController.index = 1;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text('All Members'),
              onTap: () {
                _tabController.index = 2;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.receipt),
              title: Text('Reports'),
              onTap: () {
                _tabController.index = 3;
                Navigator.pop(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('authToken');
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Dashboard'),
                  Tab(text: 'Add Member'),
                  Tab(text: 'All Members'),
                  Tab(text: 'Add Officer'),
                  Tab(text: 'Reports'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. Dashboard Tab
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overseer Summary',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: color.primaryColorDark,
                            ),
                          ),
                          SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isTwoColumn = constraints.maxWidth > 500;
                              return isTwoColumn
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildDashboardCard(
                                            context: context,
                                            title: 'Total Members',
                                            countFuture:
                                                _getTotalOverseerMemberCount,
                                            icon: Icons.group,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: _buildDashboardCard(
                                            context: context,
                                            title: 'Total Districts',
                                            countFuture:
                                                _getTotalOverseerDistrictCount,
                                            icon: Icons.location_city,
                                            backgroundColor: color.splashColor,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: _buildDashboardCard(
                                            context: context,
                                            title: 'Total Branches',
                                            countFuture:
                                                _getTotalOverseerBranchCount,
                                            icon: Icons.location_city,
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _buildDashboardCard(
                                          context: context,
                                          title: 'Total Members',
                                          countFuture:
                                              _getTotalOverseerMemberCount,
                                          icon: Icons.group,
                                        ),
                                        SizedBox(height: 16),
                                        _buildDashboardCard(
                                          context: context,
                                          title: 'Total Districts',
                                          countFuture:
                                              _getTotalOverseerDistrictCount,
                                          icon: Icons.location_city,
                                          backgroundColor: color.splashColor,
                                        ),
                                        SizedBox(height: 16),
                                        _buildDashboardCard(
                                          context: context,
                                          title: 'Total Branches',
                                          countFuture:
                                              _getTotalOverseerBranchCount,
                                          icon: Icons.location_city,
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      ],
                                    );
                            },
                          ),
                          SizedBox(height: 30),
                          _buildTitheBarChart(context), // The bar chart
                          SizedBox(height: 20),
                          _buildMemberPieChart(context), // <-- NEW PIE CHART
                          SizedBox(height: 20),
                          _buildWeeklyTitheLineChart(
                            context,
                          ), // <-- NEW LINE CHART
                          SizedBox(height: 20),
                        ],
                      ),
                    ),

                    // 2. Add Member Tab
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        width: !isWiderScreen ? 300 : double.infinity,
                        child: ListView(
                          children: [
                            _platformTextField(
                              controller: memberNameController,
                              placeholder: 'Enter Member Name',
                            ),
                            _platformTextField(
                              controller: memberSurnameController,
                              placeholder: 'Enter Member Surname',
                            ),
                            _platformTextField(
                              controller: memberEmailController,
                              placeholder: 'Enter Member Email (Optional)',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _platformTextField(
                              controller: memberAddressController,
                              placeholder: 'Enter Member Address',
                            ),
                            _platformTextField(
                              controller: memberContactController,
                              placeholder: 'Enter Contact Number',
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: 10),

                            // Dropdown selection for District Elder and Community Name
                            FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('overseers')
                                  .where(
                                    'uid',
                                    isEqualTo:
                                        FirebaseAuth.instance.currentUser!.uid,
                                  )
                                  .get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: CupertinoActivityIndicator(),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return Center(
                                    child: Text('No overseer data found.'),
                                  );
                                }
                                var overseerData =
                                    snapshot.data!.docs.first.data()
                                        as Map<String, dynamic>;
                                selectedProvince = overseerData['province'];
                                List<dynamic> districts =
                                    overseerData['districts'] ?? [];

                                Map<String, dynamic>? selectedDistrict;
                                try {
                                  selectedDistrict = districts.firstWhere(
                                    (d) =>
                                        d['districtElderName'] ==
                                        selectedDistrictElder,
                                  );
                                } catch (_) {
                                  selectedDistrict = null;
                                }

                                List<String> districtElderNames = districts
                                    .map(
                                      (d) => d['districtElderName'] as String?,
                                    )
                                    .where((name) => name != null)
                                    .cast<String>()
                                    .toSet()
                                    .toList();

                                List<String> communityNames =
                                    selectedDistrict != null
                                    ? (selectedDistrict['communities']
                                                  as List<dynamic>?)
                                              ?.map(
                                                (c) =>
                                                    c['communityName']
                                                        as String?,
                                              )
                                              .where((name) => name != null)
                                              .cast<String>()
                                              .toSet()
                                              .toList() ??
                                          []
                                    : [];

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        labelText: 'Choose a District Elder',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 12.0,
                                        ),
                                      ),
                                      menuMaxHeight: 300,
                                      value: selectedDistrictElder,
                                      hint: Text('Choose a District Elder'),
                                      items: districtElderNames
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedDistrictElder = value;
                                          selectedCommunityName = null;
                                        });
                                      },
                                    ),
                                    SizedBox(height: 10),
                                    if (selectedDistrictElder != null)
                                      DropdownButtonFormField<String>(
                                        decoration: InputDecoration(
                                          labelText: 'Choose a Community Name',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10.0,
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                            vertical: 12.0,
                                          ),
                                        ),
                                        menuMaxHeight: 300,
                                        value: selectedCommunityName,
                                        hint: Text('Choose a Community Name'),
                                        items: communityNames
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            selectedCommunityName = value;
                                          });
                                        },
                                      ),
                                    SizedBox(height: 20),
                                  ],
                                );
                              },
                            ),
                            CustomOutlinedButton(
                              onPressed: () async {
                                if (memberNameController.text.isEmpty ||
                                    memberSurnameController.text.isEmpty ||
                                    memberAddressController.text.isEmpty ||
                                    memberContactController.text.isEmpty ||
                                    selectedDistrictElder == null ||
                                    selectedCommunityName == null) {
                                  Api().showMessage(
                                    context,
                                    'Please fill in all required fields and select District/Community.',
                                    'Error',
                                    color.primaryColorDark,
                                  );
                                  return;
                                }
                                try {
                                  Api().showLoading(context);
                                  FirebaseFirestore firestore =
                                      FirebaseFirestore.instance;
                                  await firestore.collection('users').add({
                                    'name': memberNameController.text,
                                    'surname': memberSurnameController.text,
                                    'email': memberEmailController.text,
                                    'address': memberAddressController.text,
                                    'phone': memberContactController.text,
                                    'overseerUid':
                                        FirebaseAuth.instance.currentUser?.uid,
                                    'role': 'Member',
                                    'week1': 0.00,
                                    'week2': 0.00,
                                    'week3': 0.00,
                                    'week4': 0.00,
                                    "province": selectedProvince,
                                    "districtElderName": selectedDistrictElder,
                                    "communityName": selectedCommunityName,
                                  });
                                  Navigator.of(context).pop();
                                  Api().showMessage(
                                    context,
                                    'Member added successfully',
                                    'Success',
                                    color.splashColor,
                                  );
                                } catch (error) {
                                  Navigator.of(context).pop();
                                  Api().showMessage(
                                    context,
                                    'Failed to add member: $error',
                                    'Error',
                                    color.primaryColorDark,
                                  );
                                }

                                memberNameController.clear();
                                memberSurnameController.clear();
                                memberEmailController.clear();
                                memberAddressController.clear();
                                memberContactController.clear();
                                setState(() {
                                  selectedDistrictElder = null;
                                  selectedCommunityName = null;
                                  _loadDashboardData(); // Reload chart data
                                });
                              },
                              text: 'Add Member',
                              backgroundColor: color.primaryColor,
                              foregroundColor: color.scaffoldBackgroundColor,
                              width: double.infinity,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. All Members Tab
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .where(
                            'overseerUid',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                          )
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text('No members found.'));
                        }

                        final allMembers = snapshot.data!.docs;
                        final query = _searchController.text.toLowerCase();

                        // --- UPDATED FILTER LOGIC ---
                        final filteredMembers = allMembers.where((member) {
                          final name = member['name']?.toLowerCase() ?? '';
                          final surname =
                              member['surname']?.toLowerCase() ?? '';
                          final email =
                              member['email']?.toLowerCase() ?? ''; // Get email

                          return name.contains(query) ||
                              surname.contains(query) ||
                              email.contains(query); // Check email
                        }).toList();
                        // ----------------------------

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _platformTextField(
                                controller: _searchController,
                                placeholder:
                                    'Search Members by Name/Surname/Email',
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: filteredMembers.length,
                                itemBuilder: (context, index) {
                                  final member = filteredMembers[index];
                                  return Card(
                                    elevation: 5,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.person_pin,
                                        color: color.primaryColor,
                                      ),
                                      title: Text(
                                        '${member['name']} ${member['surname'] ?? ''}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                "${member['districtElderName'] ?? 'No District'} | ${member['communityName'] ?? ''}",
                                              ),
                                            ],
                                          ),
                                          if (member['phone'] != null &&
                                              member['phone'].isNotEmpty)
                                            Text(member['phone']),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () async {
                                          week1Controller.text =
                                              member['week1']?.toString() ??
                                              '0.00';
                                          week2Controller.text =
                                              member['week2']?.toString() ??
                                              '0.00';
                                          week3Controller.text =
                                              member['week3']?.toString() ??
                                              '0.00';
                                          week4Controller.text =
                                              member['week4']?.toString() ??
                                              '0.00';

                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: color
                                                  .scaffoldBackgroundColor
                                                  .withOpacity(0.95),
                                              title: Text(
                                                'Edit Tithe Offerings for ${member['name']}',
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _platformTextField(
                                                    controller: week1Controller,
                                                    placeholder: 'Week 1',
                                                    keyboardType:
                                                        TextInputType.numberWithOptions(decimal: true),
                                                  ),
                                                  _platformTextField(
                                                    controller: week2Controller,
                                                    placeholder: 'Week 2',
                                                    keyboardType:
                                                        TextInputType.numberWithOptions(decimal: true),
                                                  ),
                                                  _platformTextField(
                                                    controller: week3Controller,
                                                    placeholder: 'Week 3',
                                                    keyboardType:
                                                        TextInputType.numberWithOptions(decimal: true),
                                                  ),
                                                  _platformTextField(
                                                    controller: week4Controller,
                                                    placeholder: 'Week 4',
                                                    keyboardType:
                                                        TextInputType.numberWithOptions(decimal: true),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    Api().showLoading(context);
                                                    week1 =
                                                        double.tryParse(
                                                          week1Controller.text,
                                                        ) ??
                                                        0.0;
                                                    week2 =
                                                        double.tryParse(
                                                          week2Controller.text,
                                                        ) ??
                                                        0.0;
                                                    week3 =
                                                        double.tryParse(
                                                          week3Controller.text,
                                                        ) ??
                                                        0.0;
                                                    week4 =
                                                        double.tryParse(
                                                          week4Controller.text,
                                                        ) ??
                                                        0.0;

                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .doc(member.id)
                                                        .update({
                                                          'week1': week1,
                                                          'week2': week2,
                                                          'week3': week3,
                                                          'week4': week4,
                                                        });

                                                    Navigator.pop(context);
                                                    Navigator.pop(context);

                                                    week1Controller.clear();
                                                    week2Controller.clear();
                                                    week3Controller.clear();
                                                    week4Controller.clear();

                                                    Api().showMessage(
                                                      context,
                                                      'Member updated successfully',
                                                      'Success',
                                                      color.splashColor,
                                                    );
                                                    setState(() {
                                                      _loadDashboardData(); // Reload chart data
                                                    });
                                                  },
                                                  child: Text('Save'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Column(
                      children: [
                        Text('Add Officer'),

                        _platformTextField(
                          controller: officerNameController,
                          placeholder: 'District Initials & surname',
                        ),
                        _platformTextField(
                          controller: communityOfficerController,
                          placeholder: 'Enter community name',
                        ),
                        SizedBox(height: 10),
                        CustomOutlinedButton(
                          onPressed: () async {
                            if (officerNameController.text.isEmpty ||
                                communityOfficerController.text.isEmpty) {
                              Api().showMessage(
                                context,
                                'Please fill in all required fields.',
                                'Error',
                                color.primaryColorDark,
                              );
                              return;
                            }
                            try {
                              Api().showLoading(context);
                              FirebaseFirestore firestore =
                                  FirebaseFirestore.instance;
                              await firestore
                                  .collection('overseers')
                                  .doc(FirebaseAuth.instance.currentUser?.uid)
                                  .update({
                                    'districts': FieldValue.arrayUnion([
                                      {
                                        'districtElderName':
                                            officerNameController.text,
                                        'communities': [
                                          {
                                            'communityName':
                                                communityOfficerController.text,
                                          },
                                        ],
                                      },
                                    ]),
                                  });
                              Navigator.of(context).pop();
                              Api().showMessage(
                                context,
                                'Officer added successfully',
                                'Success',
                                color.splashColor,
                              );
                            } catch (error) {
                              Navigator.of(context).pop();
                              Api().showMessage(
                                context,
                                'Failed to add officer: $error',
                                'Error',
                                color.primaryColorDark,
                              );
                            }

                            officerNameController.clear();
                            communityOfficerController.clear();
                          },
                          text: 'Add Officer',
                          backgroundColor: color.primaryColor,
                          foregroundColor: color.scaffoldBackgroundColor,
                          width: double.infinity,
                        ),
                      ],
                    ),
                    // 4. Reports Tab
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('overseers')
                            .where(
                              'uid',
                              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                            )
                            .get(),
                        builder: (context, asyncSnapshot) {
                          Map<String, dynamic> overseerData =
                              (asyncSnapshot.data?.docs.first.data()
                                  as Map<String, dynamic>?) ??
                              {};
                          if (asyncSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (overseerData.isEmpty) {
                            return Center(
                              child: Text('No overseer data found.'),
                            );
                          }

                          String overseerInitialsAndSurname =
                              overseerData["overseerInitialsAndSurname"] ??
                              'N/A';
                          String code = overseerData['code'] ?? '';
                          String region = overseerData['region'] ?? '';

                          List<dynamic> districts =
                              overseerData['districts'] ?? [];

                          List<String> districtElderNames = (districts)
                              .map((d) => d['districtElderName'] as String?)
                              .where((name) => name != null)
                              .cast<String>()
                              .toSet()
                              .toList();

                          Map<String, dynamic>? currentDistrictData;
                          if (selectedDistrictElder != null) {
                            try {
                              currentDistrictData = districts.firstWhere(
                                (d) =>
                                    d['districtElderName'] ==
                                    selectedDistrictElder,
                              );
                            } catch (_) {
                              currentDistrictData = null;
                            }
                          }

                          List<String> communityNames =
                              currentDistrictData != null
                              ? (currentDistrictData['communities']
                                            as List<dynamic>?)
                                        ?.map(
                                          (c) => c['communityName'] as String?,
                                        )
                                        .where((name) => name != null)
                                        .cast<String>()
                                        .toSet()
                                        .toList() ??
                                    []
                              : [];

                          return Center(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Generate Report',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: color.primaryColor,
                                  ),
                                ),
                                SizedBox(height: 20),
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText:
                                        'Select District Elder for Report',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                      vertical: 12.0,
                                    ),
                                  ),
                                  menuMaxHeight: 300,
                                  value: selectedDistrictElder,
                                  items: districtElderNames
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedDistrictElder = value;
                                      selectedCommunityName = null;
                                    });
                                  },
                                ),
                                SizedBox(height: 10),
                                if (selectedDistrictElder != null)
                                  DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      labelText:
                                          'Select Community Name for Report',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          10.0,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                        vertical: 12.0,
                                      ),
                                    ),
                                    menuMaxHeight: 300,
                                    value: selectedCommunityName,
                                    items: communityNames
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedCommunityName = value;
                                      });
                                    },
                                  ),
                                SizedBox(height: 30),
                                CustomOutlinedButton(
                                  onPressed: () async {
                                    if (selectedDistrictElder == null ||
                                        selectedCommunityName == null) {
                                      Api().showMessage(
                                        context,
                                        'Please select both a District Elder and a Community Name.',
                                        'Error',
                                        color.primaryColorDark,
                                      );
                                      return;
                                    }

                                    int totalOverseerMembers =
                                        await _getTotalOverseerMemberCount();
                                    await _checkSubscriptionStatusFromFirestore();

                                    int memberLimit = 999999;
                                    if (totalOverseerMembers > 99 &&
                                        !_isSubscriptionActive) {
                                      memberLimit = 99;

                                      final currentTierAmount =
                                          _determineSubscriptionAmount(
                                            totalOverseerMembers,
                                          );
                                      showCupertinoDialog(
                                        context: context,
                                        builder: (ctx) => CupertinoAlertDialog(
                                          title: const Text(
                                            'Unlock Unlimited Reporting',
                                          ),
                                          content: Text(
                                            'Your member count is $totalOverseerMembers. Subscribing will unlock unlimited reporting and authorize your card for monthly billing at R${(currentTierAmount / 100).toStringAsFixed(2)}.',
                                          ),
                                          actions: [
                                            CupertinoDialogAction(
                                              child: const Text('Cancel'),
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                            ),
                                            CupertinoDialogAction(
                                              child: const Text(
                                                'Authorize Card Now',
                                              ),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _initiatePaystackSubscription(
                                                  totalOverseerMembers,
                                                  context,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                      // Return here if we showed the dialog, waiting for the user to subscribe
                                      return;
                                    }

                                    // Proceed only if subscribed or under the free member limit
                                    if (_isSubscriptionActive ||
                                        totalOverseerMembers <= 99) {
                                      await _generatePdfAndDownload(
                                        selectedDistrictElder!,
                                        selectedCommunityName!,
                                        selectedProvince,
                                        overseerInitialsAndSurname,
                                        overseerData,
                                        memberLimit,
                                        code,
                                        region,
                                      );
                                    }
                                  },
                                  text: 'Generate Balance Sheet (PDF)',
                                  backgroundColor: color.primaryColor,
                                  foregroundColor:
                                      color.scaffoldBackgroundColor,
                                  width: double.infinity,
                                ),

                                // Padding(
                                //  padding: const EdgeInsets.only(top: 8.0),
                                //  child: Text(
                                //   'Report limited to 99 members until subscription is active.',
                                //   style: TextStyle(color: Colors.red),
                                //  ),
                                // ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODIFIED PDF Generation Logic for Web Compatibility (The Fix) ---

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

    if (memberLimit < 999999) {
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
