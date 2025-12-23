// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_web_libraries_in_flutter, use_build_context_synchronously

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';

// --- Data Models ---

class DistrictElderModel {
  final String name;
  final String subLoc;
  final double income;
  final double expenseRent;
  final double expenseWine;
  final double expenseCentral;
  final double expenseOther;
  final double bankedOverride;
  final String remarks;

  DistrictElderModel({
    required this.name,
    this.subLoc = '',
    this.income = 0.0,
    this.expenseRent = 0.0,
    this.expenseWine = 0.0,
    this.expenseCentral = 0.0,
    this.expenseOther = 0.0,
    this.bankedOverride = 0.0,
    this.remarks = '',
  });

  double get totalExpenses =>
      expenseRent + expenseWine + expenseCentral + expenseOther;

  double get totalBanked =>
      bankedOverride != 0.0 ? bankedOverride : (income - totalExpenses);
}

class OverseerEntry {
  final String overseerName;
  final String code;
  final String region;
  final String province;
  final List<DistrictElderModel> elders;

  OverseerEntry({
    required this.overseerName,
    required this.code,
    required this.region,
    required this.province,
    required this.elders,
  });

  double get totalIncome => elders.fold(0, (sum, item) => sum + item.income);
  double get totalBanked =>
      elders.fold(0, (sum, item) => sum + item.totalBanked);
}

// --- Main Widget ---

class OverseerBalancesheetGlobal extends StatefulWidget {
  const OverseerBalancesheetGlobal({super.key});

  @override
  State<OverseerBalancesheetGlobal> createState() =>
      _OverseerBalancesheetGlobalState();
}

class _OverseerBalancesheetGlobalState
    extends State<OverseerBalancesheetGlobal> {
  bool _isLoading = true;
  List<OverseerEntry> _allOverseers = [];
  List<OverseerEntry> _filteredOverseers = [];

  // Filters
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();

  String _selectedProvince = 'All';
  final List<String> _provinces = [
    'All',
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Free State',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Northern Cape',
  ];

  String _selectedMonth = 'All';
  String _selectedYear = 'All';

  final List<String> _months = [
    'All',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<String> _years =
      ['All'] + List.generate(10, (index) => (2024 + index).toString());

  final currencyFormat = NumberFormat.currency(locale: 'en_ZA', symbol: 'R');
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _fetchDataOptimized();

    _loadLogoBytes();
  }

  // --- 1. DATA FETCHING ---
  Future<void> _fetchDataOptimized() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('overseers').get(),
        FirebaseFirestore.instance.collection('users').get(),
        FirebaseFirestore.instance
            .collection('overseer_expenses_reports')
            .get(),
      ]);

      final overseerSnapshot = results[0];
      final userSnapshot = results[1];
      final expenseSnapshot = results[2];

      final now = DateTime.now();
      final currentMonthName = DateFormat('MMMM').format(now);
      final currentYearStr = now.year.toString();

      bool isCurrentPeriod =
          (_selectedMonth == 'All' || _selectedMonth == currentMonthName) &&
          (_selectedYear == 'All' || _selectedYear == currentYearStr);

      Map<String, List<QueryDocumentSnapshot>> usersByOverseer = {};
      if (isCurrentPeriod) {
        for (var userDoc in userSnapshot.docs) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final uid = userData['overseerUid'] as String?;
          final bool isArchived = userData['archived'] ?? false;

          if (uid != null && !isArchived) {
            if (!usersByOverseer.containsKey(uid)) usersByOverseer[uid] = [];
            usersByOverseer[uid]!.add(userDoc);
          }
        }
      }

      Map<String, Map<String, Map<String, Map<String, double>>>> expensesMap =
          {};

      for (var doc in expenseSnapshot.docs) {
        final data = doc.data();
        if (_selectedMonth != 'All') {
          final rMonth = (data['month'] ?? '').toString().trim();
          if (rMonth.toLowerCase() != _selectedMonth.toLowerCase()) continue;
        }
        if (_selectedYear != 'All') {
          final rYear = (data['year'] ?? '').toString().trim();
          if (rYear != _selectedYear) continue;
        }

        final String oUid = data['overseerUid'] ?? '';
        final String dName = data['districtElderName'] ?? 'Direct';
        final String cName = data['communityName'] ?? 'Main';

        if (oUid.isEmpty) continue;

        if (!expensesMap.containsKey(oUid)) expensesMap[oUid] = {};
        if (!expensesMap[oUid]!.containsKey(dName))
          expensesMap[oUid]![dName] = {};
        if (!expensesMap[oUid]![dName]!.containsKey(cName)) {
          expensesMap[oUid]![dName]![cName] = {
            'income': 0.0,
            'rent': 0.0,
            'wine': 0.0,
            'central': 0.0,
            'other': 0.0,
            'banked': 0.0,
          };
        }

        var current = expensesMap[oUid]![dName]![cName]!;
        current['income'] =
            current['income']! + (data['totalIncome'] as num? ?? 0.0);
        current['rent'] =
            current['rent']! + (data['expenseRent'] as num? ?? 0.0);
        current['wine'] =
            current['wine']! + (data['expenseWine'] as num? ?? 0.0);
        current['central'] =
            current['central']! + (data['expenseCentral'] as num? ?? 0.0);
        current['other'] =
            current['other']! + (data['expenseOther'] as num? ?? 0.0);
        current['banked'] =
            current['banked']! + (data['totalBanked'] as num? ?? 0.0);
      }

      List<OverseerEntry> tempOverseers = [];

      for (var doc in overseerSnapshot.docs) {
        final data = doc.data();
        final String uid = data['uid'] ?? '';
        final String name = data['overseerInitialsAndSurname'] ?? 'Unknown';
        final String code = data['code'] ?? '';
        final String region = data['region'] ?? 'Unknown';
        final String province = data['province'] ?? 'Unknown';

        final myUsers = usersByOverseer[uid] ?? [];
        Map<String, Map<String, double>> aggregatedIncome = {};

        for (var userDoc in myUsers) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final String dName = (userData['districtElderName'] ?? '').trim();
          final String cName = (userData['communityName'] ?? 'Main').trim();

          final double w1 = (userData['week1'] as num? ?? 0.0).toDouble();
          final double w2 = (userData['week2'] as num? ?? 0.0).toDouble();
          final double w3 = (userData['week3'] as num? ?? 0.0).toDouble();
          final double w4 = (userData['week4'] as num? ?? 0.0).toDouble();
          final double total = w1 + w2 + w3 + w4;

          final districtKey = dName.isEmpty ? "Direct" : dName;

          if (!aggregatedIncome.containsKey(districtKey)) {
            aggregatedIncome[districtKey] = {};
          }
          if (!aggregatedIncome[districtKey]!.containsKey(cName)) {
            aggregatedIncome[districtKey]![cName] = 0.0;
          }
          aggregatedIncome[districtKey]![cName] =
              aggregatedIncome[districtKey]![cName]! + total;
        }

        final List<dynamic> rawDistricts = data['districts'] ?? [];
        for (var dist in rawDistricts) {
          String dName = (dist['districtElderName'] ?? '').trim();
          if (dName.isEmpty) dName = "Direct";

          if (!aggregatedIncome.containsKey(dName))
            aggregatedIncome[dName] = {};
          final List<dynamic> rawCommunities = dist['communities'] ?? [];
          for (var comm in rawCommunities) {
            String cName = (comm['communityName'] ?? '').trim();
            if (cName.isNotEmpty &&
                !aggregatedIncome[dName]!.containsKey(cName)) {
              aggregatedIncome[dName]![cName] = 0.0;
            }
          }
        }

        if (expensesMap.containsKey(uid)) {
          expensesMap[uid]!.forEach((dName, comms) {
            if (!aggregatedIncome.containsKey(dName))
              aggregatedIncome[dName] = {};
            comms.forEach((cName, val) {
              if (!aggregatedIncome[dName]!.containsKey(cName)) {
                aggregatedIncome[dName]![cName] = 0.0;
              }
            });
          });
        }

        List<DistrictElderModel> elderEntries = [];
        aggregatedIncome.forEach((elderName, communities) {
          bool isFirst = true;
          double groupTotalIncome = 0;
          double groupTotalBanked = 0;
          bool isDirectGroup = elderName == "Direct";

          communities.forEach((communityName, liveIncome) {
            double exRent = 0;
            double exWine = 0;
            double exCentral = 0;
            double exOther = 0;
            double archivedIncome = 0;
            double archivedBanked = 0;

            if (expensesMap.containsKey(uid) &&
                expensesMap[uid]!.containsKey(elderName) &&
                expensesMap[uid]![elderName]!.containsKey(communityName)) {
              var exData = expensesMap[uid]![elderName]![communityName]!;
              exRent = exData['rent']!;
              exWine = exData['wine']!;
              exCentral = exData['central']!;
              exOther = exData['other']!;
              archivedIncome = exData['income']!;
              archivedBanked = exData['banked']!;
            }

            double combinedIncome = liveIncome + archivedIncome;

            var model = DistrictElderModel(
              name: isDirectGroup ? "" : (isFirst ? elderName : ""),
              subLoc: communityName,
              income: combinedIncome,
              expenseRent: exRent,
              expenseWine: exWine,
              expenseCentral: exCentral,
              expenseOther: exOther,
              bankedOverride: archivedBanked > 0 ? archivedBanked : 0.0,
            );

            elderEntries.add(model);
            isFirst = false;

            groupTotalIncome += combinedIncome;
            groupTotalBanked += model.totalBanked;
          });

          if (!isDirectGroup && communities.length > 1) {
            elderEntries.add(
              DistrictElderModel(
                name: "",
                subLoc: "D/E Total",
                income: groupTotalIncome,
                bankedOverride: groupTotalBanked,
                expenseRent: 0,
              ),
            );
          }
        });

        if (elderEntries.isEmpty) {
          elderEntries.add(
            DistrictElderModel(name: "-", subLoc: "No Activity"),
          );
        }

        tempOverseers.add(
          OverseerEntry(
            overseerName: name,
            code: code,
            region: region,
            province: province,
            elders: elderEntries,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allOverseers = tempOverseers;
          _isLoading = false;
        });
        _filterData();
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    setState(() {
      var temp = _allOverseers;

      if (_selectedProvince != 'All') {
        temp = temp.where((o) => o.province == _selectedProvince).toList();
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        temp = temp.where((o) {
          final matchOverseer = o.overseerName.toLowerCase().contains(q);
          final matchDistrict = o.elders.any(
            (e) => e.name.toLowerCase().contains(q),
          );
          final matchCode = o.code.toLowerCase().contains(q);
          return matchOverseer || matchDistrict || matchCode;
        }).toList();
      }

      _filteredOverseers = temp;
    });
  }

  Future<void> _loadLogoBytes() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      setState(() => _logoBytes = bytes.buffer.asUint8List());
    } catch (e) {
      print("Error loading logo: $e");
    }
  }

  // --- 2. GENERATE PDF (Updated to include Code & Region) ---
  Future<void> _generatePdfReport() async {
    try {
      isIOSPlatform
          ? Api().showIosLoading(context)
          : Api().showLoading(context);
      if (_filteredOverseers.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("No data to print")));
        Navigator.of(context).pop();
        return;
      }

      final pdf = pw.Document();
      final font = pw.Font.helvetica();
      final boldFont = pw.Font.helveticaBold();

      final ttf = await rootBundle.load('assets/CloisterBlack.ttf');
      final cloisterFont = pw.Font.ttf(ttf);

      // Stats Calculation
      final regions = _getRegionStats();
      final topIncome = _getTopOverseers(10, true);
      final topBanked = _getTopOverseers(10, false);
      final totalIncome = _filteredOverseers.fold(
        0.0,
        (sum, o) => sum + o.totalIncome,
      );
      final totalBanked = _filteredOverseers.fold(
        0.0,
        (sum, o) => sum + o.totalBanked,
      );

      // Detailed Table Data
      final List<List<String>> tableData = [];
      for (var o in _filteredOverseers) {
        for (var i = 0; i < o.elders.length; i++) {
          final e = o.elders[i];
          final isFirst = i == 0;
          String f(double v) => v == 0 ? "-" : currencyFormat.format(v);
          tableData.add([
            isFirst ? o.overseerName : "", // 0: Overseer
            isFirst ? o.code : "", // 1: Code (ADDED)
            isFirst ? o.region : "", // 2: Region (ADDED)
            e.name, // 3: District
            e.subLoc, // 4: Community
            f(e.income), // 5: Income
            f(e.expenseRent), // 6: Rent
            f(e.expenseWine), // 7: Wine
            f(e.expenseCentral), // 8: Central
            f(e.expenseOther), // 9: Other
            f(e.totalBanked), // 10: Banked
          ]);
        }
        // Spacer row (Updated to 11 columns)
        tableData.add(["", "", "", "", "", "", "", "", "", "", ""]);
      }

      // --- PDF WIDGET HELPERS ---

      // Helper to generate Pie Charts in PDF
      pw.Widget buildPdfPieChart(String title, List<PieData> data) {
        if (data.isEmpty || data.every((e) => e.value == 0)) {
          return pw.Container(
            height: 100,
            width: 100,
            child: pw.Center(child: pw.Text("No Data")),
          );
        }
        data.sort((a, b) => b.value.compareTo(a.value));
        final chartData = data.take(8).toList();

        final colors = [
          PdfColors.blue,
          PdfColors.red,
          PdfColors.green,
          PdfColors.orange,
          PdfColors.purple,
          PdfColors.cyan,
          PdfColors.brown,
          PdfColors.pink,
        ];

        return pw.Column(
          children: [
            pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 10)),
            pw.SizedBox(height: 5),
            pw.SizedBox(
              height: 120,
              width: 120,
              child: pw.Chart(
                title: pw.Text(title),
                grid: pw.PieGrid(),
                datasets: List.generate(chartData.length, (index) {
                  return pw.PieDataSet(
                    legend: chartData[index].name,
                    value: chartData[index].value,
                    color: colors[index % colors.length],
                    legendStyle: pw.TextStyle(fontSize: 8),
                  );
                }),
              ),
            ),
          ],
        );
      }

      // Helper for Top 10 Tables in PDF
      pw.Widget buildPdfTopTable(
        String title,
        List<OverseerEntry> list,
        bool isIncome,
      ) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 10)),
            pw.Table.fromTextArray(
              headers: ['#', 'Name', 'Region', 'Amount'],
              data: list
                  .asMap()
                  .entries
                  .map(
                    (e) => [
                      (e.key + 1).toString(),
                      e.value.overseerName,
                      e.value.region,
                      currencyFormat.format(
                        isIncome ? e.value.totalIncome : e.value.totalBanked,
                      ),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontSize: 8,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blue900),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
            ),
          ],
        );
      }

      // --- BUILD PDF PAGE ---

      pw.Widget _buildHeader(pw.Font font, Uint8List? logo) {
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            if (logo != null)
              pw.Container(
                width: 160,
                height: 160,
                margin: const pw.EdgeInsets.only(right: 15),
                child: pw.Image(pw.MemoryImage(logo)),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  "The Twelve Apostles Church in Trinity",
                  style: pw.TextStyle(font: font, fontSize: 35),
                ),
                pw.Text(
                  "P. O. Box 40376, Red Hill, 4071",
                  style: pw.TextStyle(fontSize: 18, font: font),
                ),
                pw.Text(
                  "Tel. / Fax No's: (031) 569 6164",
                  style:   pw.TextStyle(fontSize: 18,font: font),
                ),
                pw.Text(
                  "Email: thetacc@telkomsa.net",
                  style: const pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.blue,
                  ),
                ),
              ],
            ),
          ],
        );
      }

      pdf.addPage(
        pw.MultiPage(
          maxPages: 1000,
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            // 1. HEADER
            _buildHeader(cloisterFont, _logoBytes),
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "$_selectedProvince Summary Balance Sheet - $_selectedMonth $_selectedYear",
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                  ),
                  pw.Text(
                    "Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                  ),
                ],
              ),
            ),
            pw.Text(
              "Filter: $_selectedProvince | Search: ${_searchQuery.isEmpty ? 'None' : _searchQuery}",
              style: pw.TextStyle(
                font: font,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 10),

            // 2. PROVINCIAL SUMMARY
            pw.Text(
              "Provincial Summary",
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 5),
            pw.Table.fromTextArray(
              headers: ['Region', 'Income', 'Banked', '% Banked'],
              data: [
                ...regions.entries.map((e) {
                  final income = e.value['income']!;
                  final banked = e.value['banked']!;
                  final pct = income > 0
                      ? (banked / income * 100).toStringAsFixed(0)
                      : "0";
                  return [
                    e.key,
                    currencyFormat.format(income),
                    currencyFormat.format(banked),
                    "$pct%",
                  ];
                }),
                [
                  'TOTAL',
                  currencyFormat.format(totalIncome),
                  currencyFormat.format(totalBanked),
                  totalIncome > 0
                      ? "${(totalBanked / totalIncome * 100).toStringAsFixed(0)}%"
                      : "0%",
                ],
              ],
              headerStyle: pw.TextStyle(
                font: boldFont,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 15),

            // 3. CHARTS ROW
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                buildPdfPieChart(
                  "Income by Region",
                  regions.entries
                      .map((e) => PieData(e.key, e.value['income']!))
                      .toList(),
                ),
                buildPdfPieChart(
                  "Top 10 Income",
                  topIncome
                      .map((e) => PieData(e.overseerName, e.totalIncome))
                      .toList(),
                ),
                buildPdfPieChart(
                  "Top 10 Banked",
                  topBanked
                      .map((e) => PieData(e.overseerName, e.totalBanked))
                      .toList(),
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // 4. TOP LISTS (Side by Side)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: buildPdfTopTable("Top 10 Income", topIncome, true),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: buildPdfTopTable("Top 10 Banked", topBanked, false),
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // 5. REGIONAL TOP 3
            pw.Text(
              "Regional Top 3 Performers",
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: regions.keys.map((region) {
                final tops = _getTopOverseersByRegion(region, 3, true);
                if (tops.isEmpty || tops.every((t) => t.totalIncome == 0))
                  return pw.SizedBox();
                return pw.Container(
                  width: 150,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        region,
                        style: pw.TextStyle(font: boldFont, fontSize: 9),
                      ),
                      ...tops.map(
                        (o) => pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                o.overseerName,
                                style: pw.TextStyle(fontSize: 8),
                                overflow: pw.TextOverflow.clip,
                              ),
                            ),
                            pw.Text(
                              currencyFormat.format(o.totalIncome),
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 20),

            // 6. DETAILED BREAKDOWN
            pw.Text(
              "Detailed Breakdown",
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 5),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              headers: [
                'Overseer',
                'Code', // ADDED
                'Region', // ADDED
                'District',
                'Community',
                'Income',
                'Rent',
                'Wine',
                'Central',
                'Other',
                'Banked',
              ],
              data: tableData,
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontSize: 7, // Smaller font for more columns
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 7),
              cellAlignments: {
                0: pw.Alignment.centerLeft, // Overseer
                1: pw.Alignment.centerLeft, // Code
                2: pw.Alignment.centerLeft, // Region
                3: pw.Alignment.centerLeft, // District
                4: pw.Alignment.centerLeft, // Community
                5: pw.Alignment.centerRight, // Income
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
                9: pw.Alignment.centerRight,
                10: pw.Alignment.centerRight, // Banked
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5), // Overseer Name
                1: const pw.FlexColumnWidth(1.0), // Code
                2: const pw.FlexColumnWidth(1.5), // Region
                3: const pw.FlexColumnWidth(2.0), // District
                4: const pw.FlexColumnWidth(2.0), // Community
              },
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context).pop();
      debugPrint("PDF Gen Error: $e");

      Api().showMessage(context, "Error message: $e", "Error", Colors.red);
    }
  }

  // --- 3. HELPER CALCULATIONS ---
  Map<String, Map<String, double>> _getRegionStats() {
    Map<String, Map<String, double>> stats = {};
    for (var o in _filteredOverseers) {
      String reg = o.region.trim().isEmpty ? 'Unknown' : o.region.trim();
      if (!stats.containsKey(reg)) stats[reg] = {'income': 0.0, 'banked': 0.0};
      stats[reg]!['income'] = stats[reg]!['income']! + o.totalIncome;
      stats[reg]!['banked'] = stats[reg]!['banked']! + o.totalBanked;
    }
    return stats;
  }

  List<OverseerEntry> _getTopOverseers(int count, bool byIncome) {
    List<OverseerEntry> list = List.from(_filteredOverseers);
    list.sort(
      (a, b) => byIncome
          ? b.totalIncome.compareTo(a.totalIncome)
          : b.totalBanked.compareTo(a.totalBanked),
    );
    var active = list
        .where((o) => byIncome ? o.totalIncome > 0 : o.totalBanked > 0)
        .toList();
    return active.take(count).toList();
  }

  List<OverseerEntry> _getTopOverseersByRegion(
    String region,
    int count,
    bool byIncome,
  ) {
    List<OverseerEntry> list = _filteredOverseers
        .where((o) => o.region.trim() == region)
        .toList();
    list.sort(
      (a, b) => byIncome
          ? b.totalIncome.compareTo(a.totalIncome)
          : b.totalBanked.compareTo(a.totalBanked),
    );
    var active = list
        .where((o) => byIncome ? o.totalIncome > 0 : o.totalBanked > 0)
        .toList();
    return active.take(count).toList();
  }

  // --- 4. UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildControls(isMobile),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? Api().isIOSPlatform
                      ? Center(
                          child: Container(
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                CupertinoActivityIndicator(),
                                Text('  Loading data...'),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Container(
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                Text('  Loading data...'),
                              ],
                            ),
                          ),
                        )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSummaryDashboard(isMobile),
                        const Divider(thickness: 2),
                        _buildChartsSection(isMobile),
                        const Divider(thickness: 2),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Detailed Breakdown",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildDetailedTable(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildDropdown<String>(
                      label: "Month",
                      value: _selectedMonth,
                      items: _months,
                      onChanged: (val) {
                        setState(() {
                          _selectedMonth = val!;
                        });
                        _fetchDataOptimized();
                      },
                    ),
                    _buildDropdown<String>(
                      label: "Year",
                      value: _selectedYear,
                      items: _years,
                      onChanged: (val) {
                        setState(() {
                          _selectedYear = val!;
                        });
                        _fetchDataOptimized();
                      },
                    ),
                    _buildDropdown<String>(
                      label: "Province",
                      value: _selectedProvince,
                      items: _provinces,
                      onChanged: (val) {
                        setState(() {
                          _selectedProvince = val!;
                          _filterData();
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                ElevatedButton.icon(
                  onPressed: _generatePdfReport,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Save PDF"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search Overseer Name, Code, or District Name...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _filterData();
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val);
              _filterData();
            },
          ),
          if (isMobile) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _generatePdfReport,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Export PDF"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required Function(T?) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButton<T>(
            value: value,
            underline: SizedBox(),
            isDense: true,
            items: items
                .map(
                  (v) => DropdownMenuItem(value: v, child: Text(v.toString())),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDashboard(bool isMobile) {
    final regions = _getRegionStats();
    final topIncome = _getTopOverseers(10, true);
    final topBanked = _getTopOverseers(10, false);
    final totalIncome = _filteredOverseers.fold(
      0.0,
      (sum, o) => sum + o.totalIncome,
    );
    final totalBanked = _filteredOverseers.fold(
      0.0,
      (sum, o) => sum + o.totalBanked,
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "$_selectedProvince Summary",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              if (_selectedMonth == 'All')
                Chip(
                  label: Text("ALL TIME"),
                  backgroundColor: Colors.blue[100],
                  labelStyle: TextStyle(color: Colors.blue[900]),
                )
              else
                Chip(
                  label: Text("$_selectedMonth $_selectedYear"),
                  backgroundColor: Colors.green[100],
                  labelStyle: TextStyle(color: Colors.green[900]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: isMobile ? double.infinity : 600,
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {0: FlexColumnWidth(2)},
              children: [
                _tableHeader(['Region', 'Income', 'Banked', '% Banked']),
                ...regions.entries.map((e) {
                  final inc = e.value['income']!;
                  final bnk = e.value['banked']!;
                  return _tableRow([
                    e.key,
                    currencyFormat.format(inc),
                    currencyFormat.format(bnk),
                    inc > 0 ? "${(bnk / inc * 100).toStringAsFixed(0)}%" : "0%",
                  ]);
                }),
                _tableRow(
                  [
                    'TOTAL',
                    currencyFormat.format(totalIncome),
                    currencyFormat.format(totalBanked),
                    totalIncome > 0
                        ? "${(totalBanked / totalIncome * 100).toStringAsFixed(0)}%"
                        : "0%",
                  ],
                  isBold: true,
                  color: Colors.blue[50],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          isMobile
              ? Column(
                  children: [
                    _buildTopListTable("Top 10 Income", topIncome, true),
                    SizedBox(height: 20),
                    _buildTopListTable("Top 10 Banked", topBanked, false),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTopListTable(
                        "Top 10 Income",
                        topIncome,
                        true,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTopListTable(
                        "Top 10 Banked",
                        topBanked,
                        false,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 30),
          const Text(
            "Regional Top 3 Performers (Income)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.start,
            children: regions.keys.map((region) {
              final tops = _getTopOverseersByRegion(region, 3, true);
              if (tops.isEmpty || tops.every((t) => t.totalIncome == 0))
                return const SizedBox();

              return Container(
                width: isMobile ? double.infinity : 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[200],
                      child: Text(
                        "$region Top 3",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...tops
                        .map(
                          (o) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  o.overseerName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  currencyFormat.format(o.totalIncome),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopListTable(
    String title,
    List<OverseerEntry> data,
    bool isIncome,
  ) {
    if (data.isEmpty) return SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FixedColumnWidth(30),
            2: FixedColumnWidth(100),
          },
          children: [
            _tableHeader(['#', 'Name', 'Region', 'Amount']),
            ...data.asMap().entries.map(
              (e) => _tableRow([
                (e.key + 1).toString(),
                e.value.overseerName,
                e.value.region,
                currencyFormat.format(
                  isIncome ? e.value.totalIncome : e.value.totalBanked,
                ),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsSection(bool isMobile) {
    final regions = _getRegionStats();
    final topIncome = _getTopOverseers(10, true);
    final topBanked = _getTopOverseers(10, false);

    List<Widget> charts = [
      _buildPieChart(
        "Income by Region",
        regions.entries.map((e) => PieData(e.key, e.value['income']!)).toList(),
      ),
      _buildPieChart(
        "Top 10 Income",
        topIncome.map((e) => PieData(e.overseerName, e.totalIncome)).toList(),
      ),
      _buildPieChart(
        "Top 10 Banked",
        topBanked.map((e) => PieData(e.overseerName, e.totalBanked)).toList(),
      ),
    ];

    if (isMobile) {
      return Column(
        children: charts
            .map(
              (chart) => Container(
                height: 300,
                margin: EdgeInsets.only(bottom: 20),
                child: chart,
              ),
            )
            .toList(),
      );
    } else {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: charts.map((chart) => Expanded(child: chart)).toList(),
        ),
      );
    }
  }

  Widget _buildPieChart(String title, List<PieData> data) {
    if (data.isEmpty || data.every((e) => e.value == 0)) {
      return const Center(child: Text("No Data"));
    }

    data.sort((a, b) => b.value.compareTo(a.value));
    final chartData = data.take(8).toList();

    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: chartData.asMap().entries.map((e) {
                final color = Colors.primaries[e.key % Colors.primaries.length];
                return PieChartSectionData(
                  color: color,
                  value: e.value.value,
                  title: '',
                  radius: 40,
                );
              }).toList(),
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: chartData.asMap().entries.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  color: Colors.primaries[e.key % Colors.primaries.length],
                ),
                const SizedBox(width: 4),
                Text(e.value.name, style: const TextStyle(fontSize: 10)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDetailedTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
        columnWidths: const {
          0: FixedColumnWidth(70), // Overseer
          1: FixedColumnWidth(30), // Code
          2: FixedColumnWidth(60), // Region
          3: FixedColumnWidth(140), // District
          4: FixedColumnWidth(130), // Details
          5: FixedColumnWidth(120), // Income
          6: FixedColumnWidth(80), // Rent
          7: FixedColumnWidth(80), // Wine
          8: FixedColumnWidth(80), // Central
          9: FixedColumnWidth(60), // Seat
          10: FixedColumnWidth(80), // Other
          11: FixedColumnWidth(90), // Exp Total
          12: FixedColumnWidth(90), // Banked
          13: FixedColumnWidth(100), // Remarks
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
            children:
                [
                      'OVERSEER',
                      'CODE',
                      'REGION',
                      'DISTRICT',
                      'DETAILS',
                      'INCOME',
                      'RENT',
                      'WINE',
                      'CENTRAL',
                      'SEAT',
                      'OTHER',
                      'EXP',
                      'BANKED',
                      'REMARKS',
                    ]
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    .toList(),
          ),
          ..._filteredOverseers.expand((o) {
            return o.elders.asMap().entries.map((entry) {
              final e = entry.value;
              final isFirst = entry.key == 0;
              final isTotal = e.subLoc == "D/E Total";
              String valOrDash(double val) =>
                  val == 0 ? "-" : currencyFormat.format(val);

              return TableRow(
                decoration: BoxDecoration(
                  color: isTotal ? Colors.blue[50] : Colors.white,
                ),
                children: [
                  _DataCell(isFirst ? o.overseerName : "", isBold: true),
                  _DataCell(isFirst ? o.code : ""),
                  _DataCell(isFirst ? o.region : ""),
                  _DataCell(e.name, isBold: true),
                  _DataCell(e.subLoc, isBold: isTotal),
                  _DataCell(
                    valOrDash(e.income),
                    align: TextAlign.right,
                    isBold: isTotal,
                  ),
                  _DataCell(valOrDash(e.expenseRent), align: TextAlign.right),
                  _DataCell(valOrDash(e.expenseWine), align: TextAlign.right),
                  _DataCell(
                    valOrDash(e.expenseCentral),
                    align: TextAlign.right,
                  ),
                  _DataCell("-", align: TextAlign.right),
                  _DataCell(valOrDash(e.expenseOther), align: TextAlign.right),
                  _DataCell(
                    valOrDash(e.totalExpenses),
                    align: TextAlign.right,
                    isBold: isTotal,
                  ),
                  _DataCell(
                    valOrDash(e.totalBanked),
                    align: TextAlign.right,
                    isBold: isTotal,
                  ),
                  _DataCell(e.remarks),
                ],
              );
            });
          }),
        ],
      ),
    );
  }

  TableRow _tableHeader(List<String> texts) {
    return TableRow(
      decoration: const BoxDecoration(color: Color.fromARGB(255, 5, 32, 73)),
      children: texts
          .map(
            (t) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                t,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _tableRow(List<String> texts, {bool isBold = false, Color? color}) {
    return TableRow(
      decoration: BoxDecoration(color: color ?? Colors.white),
      children: texts
          .map(
            (t) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                t,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool isBold;
  final TextAlign align;
  const _DataCell(
    this.text, {
    this.isBold = false,
    this.align = TextAlign.left,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
        ),
        textAlign: align,
      ),
    );
  }
}

class PieData {
  final String name;
  final double value;
  PieData(this.name, this.value);
}
