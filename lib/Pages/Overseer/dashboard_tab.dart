import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DashboardTab extends StatefulWidget {
  final bool isLargeScreen;
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;

  const DashboardTab({
    super.key,
    required this.isLargeScreen,
    required this.committeeMemberName,
    required this.committeeMemberRole,
    required this.faceUrl,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  // --- CHART DATA STATE ---
  List<BarChartGroupData> _monthlyOfferingsData = [];
  Map<String, double> _districtTotals = {};
  double _maxOfferingAmount = 100.0;

  Map<String, int> _districtMemberCounts = {};
  int _totalMemberCountForChart = 0;

  Map<int, double> _weeklyTotals = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
  double _maxWeeklyTithe = 100.0;

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
    _loadDashboardData();
  }

  // --- DATA FETCHING LOGIC ---

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

        // Parse Weeks safely
        final w1 = (data['week1'] as num? ?? 0.0).toDouble();
        final w2 = (data['week2'] as num? ?? 0.0).toDouble();
        final w3 = (data['week3'] as num? ?? 0.0).toDouble();
        final w4 = (data['week4'] as num? ?? 0.0).toDouble();
        final monthlyTotal = w1 + w2 + w3 + w4;

        // Update District Totals
        districtTitheTotals.update(
          districtName,
          (v) => v + monthlyTotal,
          ifAbsent: () => monthlyTotal,
        );

        // Update District Member Counts
        districtMemberCounts.update(
          districtName,
          (v) => v + 1,
          ifAbsent: () => 1,
        );

        // Update Weekly Totals
        weeklyTitheTotals[1] = (weeklyTitheTotals[1] ?? 0) + w1;
        weeklyTitheTotals[2] = (weeklyTitheTotals[2] ?? 0) + w2;
        weeklyTitheTotals[3] = (weeklyTitheTotals[3] ?? 0) + w3;
        weeklyTitheTotals[4] = (weeklyTitheTotals[4] ?? 0) + w4;
      }

      // Prepare Bar Chart Data
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

      // Calculate Max Weekly for Line Chart Scaling
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
      debugPrint("Error loading dashboard data: $e");
    }
  }

  // --- STAT FETCHERS ---

  Future<int> _getTotalOverseerMemberCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    // In production, uncomment the query. Using cached/snapshot count is better for reads.
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('overseerUid', isEqualTo: uid)
        .count()
        .get();
    return snapshot.count ?? 0;
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

  // --- BUILD METHOD ---

  final Color _primaryColor = const Color(0xFF1E3A8A);
  final Color _accentColor = const Color(0xFF3B82F6);
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_primaryColor, _accentColor]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: widget.faceUrl != null && widget.faceUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(
                              height: 100,
                              width: 100,
                              widget.faceUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.person, color: Colors.white),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome Back,",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        // DISPLAY THE LOGGED IN MEMBER'S NAME & ROLE
                        Text(
                          widget.committeeMemberName != null
                              ? "${widget.committeeMemberName} (${widget.committeeMemberRole})"
                              : " Overseer",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            Text(
              "Overview",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 20),

            // 1. STAT CARDS (Responsive Wrap)
            LayoutBuilder(
              builder: (ctx, constraints) {
                int crossAxisCount = widget.isLargeScreen
                    ? 3
                    : (constraints.maxWidth > 600 ? 2 : 1);
                final color = Theme.of(context);

                // Calculate width for cards
                double cardWidth =
                    (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                    crossAxisCount;

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
                      width: cardWidth,
                    ),
                    _buildStatCard(
                      "Total Districts",
                      Icons.map,
                      Colors.orange,
                      color.splashColor,
                      _getTotalOverseerDistrictCount,
                      width: cardWidth,
                    ),
                    _buildStatCard(
                      "Total Branches",
                      Icons.location_city,
                      Colors.red,
                      color.primaryColorDark,
                      _getTotalOverseerBranchCount,
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            // 2. CHARTS (Bar + Pie)
            widget.isLargeScreen
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTitheBarChart(context)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildMemberPieChart(context)),
                    ],
                  )
                : Column(
                    children: [
                      _buildTitheBarChart(context),
                      const SizedBox(height: 20),
                      _buildMemberPieChart(context),
                    ],
                  ),

            const SizedBox(height: 20),

            // 3. WEEKLY TREND LINE CHART
            _buildWeeklyTitheLineChart(context),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

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
      constraints: const BoxConstraints(minWidth: 250),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      snapshot.connectionState == ConnectionState.waiting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              "${snapshot.data ?? 0}",
                              style: const TextStyle(
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

  // --- CHART BUILDERS ---

  Widget _buildTitheBarChart(BuildContext context) {
    final color = Theme.of(context);
    final isWeb = kIsWeb;

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
            const SizedBox(height: 10),
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
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < districtNames.length) {
                              String name = districtNames[index];
                              // Generate initials
                              String initials = name
                                  .split(' ')
                                  .map(
                                    (e) =>
                                        e.isNotEmpty ? e.substring(0, 1) : '',
                                  )
                                  .join();
                              return SideTitleWidget(
                                meta: meta,
                                space: 4.0,
                                child: Text(
                                  initials,
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
                    'Key: ${districtNames.asMap().entries.map((e) => '${e.value.split(' ').map((s) => s.isNotEmpty ? s.substring(0, 1) : '').join()}=${e.value}').join(', ')}',
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
      final double percentage = _totalMemberCountForChart > 0
          ? (count / _totalMemberCountForChart) * 100
          : 0;

      sections.add(
        PieChartSectionData(
          color: _pieColors[colorIndex % _pieColors.length],
          value: count.toDouble(),
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 100.0,
          titleStyle: TextStyle(
            fontSize: 12.0,
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
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 1,
                        centerSpaceRadius: 20,
                        sections: sections,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
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
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '$district (${_districtMemberCounts[district]})',
                                      style: const TextStyle(fontSize: 12),
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
            const SizedBox(height: 20),
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
            const SizedBox(height: 10),
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
}
