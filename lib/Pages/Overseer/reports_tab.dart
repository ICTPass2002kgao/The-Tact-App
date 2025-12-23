// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/Overseer/Services/pdf_generator_service.dart';

class ReportsTab extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;
  final Uint8List? logoBytes;

  const ReportsTab({
    super.key,
    required this.isLargeScreen,
    this.logoBytes,
    required this.committeeMemberName,
    required this.committeeMemberRole,
    required this.faceUrl,
  });

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  // --- Selection State ---
  String? _selectedDistrictElder;
  String? _selectedCommunityName;
  String _selectedProvince = '';
  Map<String, dynamic>? _overseerData;

  // --- Time Travel State ---
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isViewingHistory =
      false; // Now controlled by DB existence, not Calendar

  // --- Financial Data State ---
  double _week1Sum = 0.0;
  double _week2Sum = 0.0;
  double _week3Sum = 0.0;
  double _week4Sum = 0.0;

  // --- Date State ---
  DateTime? _dateWeek1;
  DateTime? _dateWeek2;
  DateTime? _dateWeek3;
  DateTime? _dateWeek4;
  DateTime? _dateMonthEnd;
  DateTime? _dateOthers;
  DateTime? _dateRent;
  DateTime? _dateWine;
  DateTime? _datePower;
  DateTime? _dateSundries;
  DateTime? _dateCouncil;
  DateTime? _dateEquipment;

  // --- Input Controllers ---
  final TextEditingController _monthEndController = TextEditingController();
  final TextEditingController _othersController = TextEditingController();
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _wineController = TextEditingController();
  final TextEditingController _powerController = TextEditingController();
  final TextEditingController _sundriesController = TextEditingController();
  final TextEditingController _councilController = TextEditingController();
  final TextEditingController _equipmentController = TextEditingController();

  // --- Calculated Totals ---
  double _totalIncome = 0.0;
  double _totalExpenditure = 0.0;
  double _creditBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchOverseerDetails();
    _setupListeners();
  }

  void _setupListeners() {
    _monthEndController.addListener(_calculateTotals);
    _othersController.addListener(_calculateTotals);
    _rentController.addListener(_calculateTotals);
    _wineController.addListener(_calculateTotals);
    _powerController.addListener(_calculateTotals);
    _sundriesController.addListener(_calculateTotals);
    _councilController.addListener(_calculateTotals);
    _equipmentController.addListener(_calculateTotals);
  }

  @override
  void dispose() {
    _monthEndController.dispose();
    _othersController.dispose();
    _rentController.dispose();
    _wineController.dispose();
    _powerController.dispose();
    _sundriesController.dispose();
    _councilController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  // --- 1. Fetch Basic Info ---
  Future<void> _fetchOverseerDetails() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final qs = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (qs.docs.isNotEmpty) {
        setState(() {
          _overseerData = qs.docs.first.data();
          _selectedProvince = _overseerData?['province'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching overseer: $e");
    }
  }

  // --- 2. Master Fetch Logic (UPDATED: Checks Database Existence) ---
  Future<void> _fetchData() async {
    if (_selectedDistrictElder == null || _selectedCommunityName == null) {
      return;
    }

    Api().showLoading(context);

    try {
      // Step 1: Check if this month is ALREADY archived in the database
      final docId =
          "${_selectedCommunityName}_${_selectedYear}_$_selectedMonth";
      final reportSnapshot = await FirebaseFirestore.instance
          .collection('monthly_reports')
          .doc(docId)
          .get();

      final bool isArchived = reportSnapshot.exists;

      setState(() {
        _isViewingHistory = isArchived;
      });

      // Step 2: Route to correct fetcher
      if (isArchived) {
        // It's archived (even if it's the current month), show history
        await _fetchHistoricalCommunityFinancials();
        await _fetchHistoricalReportSummary(existingSnapshot: reportSnapshot);
      } else {
        // It's not archived, show live editing
        await _fetchLiveCommunityFinancials();
        _clearFields(); // Clear report fields for new entry
      }

      _calculateTotals();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error fetching data: $e");
      Api().showMessage(context, "Error loading data", "Error", Colors.red);
    }
  }

  Future<void> _fetchLiveCommunityFinancials() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('overseerUid', isEqualTo: uid)
        .where('districtElderName', isEqualTo: _selectedDistrictElder)
        .where('communityName', isEqualTo: _selectedCommunityName)
        .get();

    double w1 = 0, w2 = 0, w3 = 0, w4 = 0;
    for (var doc in snapshot.docs) {
      final d = doc.data();
      w1 += (d['week1'] as num?)?.toDouble() ?? 0.0;
      w2 += (d['week2'] as num?)?.toDouble() ?? 0.0;
      w3 += (d['week3'] as num?)?.toDouble() ?? 0.0;
      w4 += (d['week4'] as num?)?.toDouble() ?? 0.0;
    }

    setState(() {
      _week1Sum = w1;
      _week2Sum = w2;
      _week3Sum = w3;
      _week4Sum = w4;
    });
  }

  Future<void> _fetchHistoricalCommunityFinancials() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('contribution_history')
        .where('overseerUid', isEqualTo: uid)
        .where('districtElder', isEqualTo: _selectedDistrictElder)
        .where('community', isEqualTo: _selectedCommunityName)
        .where('year', isEqualTo: _selectedYear)
        .where('month', isEqualTo: _selectedMonth)
        .get();

    double w1 = 0, w2 = 0, w3 = 0, w4 = 0;
    for (var doc in snapshot.docs) {
      final d = doc.data();
      w1 += (d['week1'] as num?)?.toDouble() ?? 0.0;
      w2 += (d['week2'] as num?)?.toDouble() ?? 0.0;
      w3 += (d['week3'] as num?)?.toDouble() ?? 0.0;
      w4 += (d['week4'] as num?)?.toDouble() ?? 0.0;
    }

    setState(() {
      _week1Sum = w1;
      _week2Sum = w2;
      _week3Sum = w3;
      _week4Sum = w4;
    });
  }

  Future<void> _fetchHistoricalReportSummary({
    required DocumentSnapshot existingSnapshot,
  }) async {
    // We already fetched the snapshot in _fetchData, so we use it directly
    final d = existingSnapshot.data() as Map<String, dynamic>;

    setState(() {
      _monthEndController.text = (d['monthEnd'] ?? 0.0).toString();
      _othersController.text = (d['others'] ?? 0.0).toString();
      _rentController.text = (d['rent'] ?? 0.0).toString();
      _wineController.text = (d['wine'] ?? 0.0).toString();
      _powerController.text = (d['power'] ?? 0.0).toString();
      _sundriesController.text = (d['sundries'] ?? 0.0).toString();
      _councilController.text = (d['council'] ?? 0.0).toString();
      _equipmentController.text = (d['equipment'] ?? 0.0).toString();

      DateTime? toDate(dynamic val) =>
          val != null ? (val as Timestamp).toDate() : null;

      _dateWeek1 = toDate(d['dateWeek1']);
      _dateWeek2 = toDate(d['dateWeek2']);
      _dateWeek3 = toDate(d['dateWeek3']);
      _dateWeek4 = toDate(d['dateWeek4']);
      _dateMonthEnd = toDate(d['dateMonthEnd']);
      _dateOthers = toDate(d['dateOthers']);
      _dateRent = toDate(d['dateRent']);
      _dateWine = toDate(d['dateWine']);
      _datePower = toDate(d['datePower']);
      _dateSundries = toDate(d['dateSundries']);
      _dateCouncil = toDate(d['dateCouncil']);
      _dateEquipment = toDate(d['dateEquipment']);
    });
  }

  void _clearFields() {
    setState(() {
      _monthEndController.clear();
      _othersController.clear();
      _rentController.clear();
      _wineController.clear();
      _powerController.clear();
      _sundriesController.clear();
      _councilController.clear();
      _equipmentController.clear();
      _dateWeek1 = null;
      _dateWeek2 = null;
      _dateWeek3 = null;
      _dateWeek4 = null;
      _dateMonthEnd = null;
      _dateOthers = null;
      _dateRent = null;
      _dateWine = null;
      _datePower = null;
      _dateSundries = null;
      _dateCouncil = null;
      _dateEquipment = null;
    });
  }

  void _calculateTotals() {
    double parse(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

    double incomeExtras = parse(_monthEndController) + parse(_othersController);
    double calculatedIncome =
        _week1Sum + _week2Sum + _week3Sum + _week4Sum + incomeExtras;

    double expenses =
        parse(_rentController) +
        parse(_wineController) +
        parse(_powerController) +
        parse(_sundriesController) +
        parse(_councilController) +
        parse(_equipmentController);

    setState(() {
      _totalIncome = calculatedIncome;
      _totalExpenditure = expenses;
      _creditBalance = _totalIncome - _totalExpenditure;
    });
  }

  // --- HELPER: Prepare PDF Data Object ---
  ReportPdfData _buildCurrentPdfData() {
    String overseerName = "Overseer";
    if (_overseerData != null) {
      String n = _overseerData!['name'] ?? '';
      String s = _overseerData!['surname'] ?? '';
      if (n.isNotEmpty || s.isNotEmpty) overseerName = "$n $s";
    }

    double parse(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

    return ReportPdfData(
      districtElder: _selectedDistrictElder!,
      communityName: _selectedCommunityName!,
      province: _selectedProvince,
      overseerName: overseerName,
      month: _selectedMonth,
      year: _selectedYear,
      logoBytes: widget.logoBytes,
      isViewingHistory: _isViewingHistory,
      week1Sum: _week1Sum,
      week2Sum: _week2Sum,
      week3Sum: _week3Sum,
      week4Sum: _week4Sum,
      monthEnd: parse(_monthEndController),
      others: parse(_othersController),
      totalIncome: _totalIncome,
      rent: parse(_rentController),
      wine: parse(_wineController),
      power: parse(_powerController),
      sundries: parse(_sundriesController),
      council: parse(_councilController),
      equipment: parse(_equipmentController),
      totalExpenditure: _totalExpenditure,
      creditBalance: _creditBalance,
      dateWeek1: _dateWeek1,
      dateWeek2: _dateWeek2,
      dateWeek3: _dateWeek3,
      dateWeek4: _dateWeek4,
      dateMonthEnd: _dateMonthEnd,
      dateOthers: _dateOthers,
      dateRent: _dateRent,
      dateWine: _dateWine,
      datePower: _datePower,
      dateSundries: _dateSundries,
      dateCouncil: _dateCouncil,
      dateEquipment: _dateEquipment,
    );
  }

  // --- HELPER: Open PDF Preview Screen ---
  void _openPdfPreviewScreen(ReportPdfData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              data.isViewingHistory
                  ? "Archived Balance Sheet"
                  : "Report Generated",
            ),
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
          ),
          body: PdfPreview(
            build: (format) =>
                PdfGeneratorService.generatePdfDocument(format, data),
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowSharing: true,
            allowPrinting: true,
            pdfFileName:
                "Report_${data.communityName}_${data.year}_${data.month}.pdf",
          ),
        ),
      ),
    );
  }

  // --- 4. Archive & Generate Logic (Combined) ---
  Future<void> _archiveAndGenerateReport() async {
    if (_selectedDistrictElder == null || _selectedCommunityName == null) {
      Api().showMessage(
        context,
        "Select a community first.",
        "Error",
        Colors.red,
      );
      return;
    }

    // Capture the data NOW before resetting
    final pdfDataToGenerate = _buildCurrentPdfData();

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠ Finalize, Archive & Generate?"),
        content: Text(
          "You are about to close the month of ${_getMonthName(_selectedMonth)} $_selectedYear.\n\n"
          "1. This will ARCHIVE all data to history.\n"
          "2. It will RESET live member contributions to 0.00.\n"
          "3. It will GENERATE the Balance Sheet PDF automatically.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("CONFIRM & GENERATE"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    Api().showLoading(context);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('overseerUid', isEqualTo: uid)
          .where('districtElderName', isEqualTo: _selectedDistrictElder)
          .where('communityName', isEqualTo: _selectedCommunityName)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // A. Archive Members
      for (var doc in snapshot.docs) {
        final d = doc.data();
        final historyRef = FirebaseFirestore.instance
            .collection('contribution_history')
            .doc();
        batch.set(historyRef, {
          'overseerUid': uid,
          'userId': doc.id,
          'name': d['name'] ?? '',
          'surname': d['surname'] ?? '',
          'districtElder': _selectedDistrictElder,
          'community': _selectedCommunityName,
          'month': _selectedMonth,
          'year': _selectedYear,
          'week1': d['week1'] ?? 0.0,
          'week2': d['week2'] ?? 0.0,
          'week3': d['week3'] ?? 0.0,
          'week4': d['week4'] ?? 0.0,
          'archivedAt': FieldValue.serverTimestamp(),
        });

        // B. Reset Live Member
        batch.update(doc.reference, {
          'week1': 0.0,
          'week2': 0.0,
          'week3': 0.0,
          'week4': 0.0,
        });
      }

      // C. Save Report
      final reportRef = FirebaseFirestore.instance
          .collection('monthly_reports')
          .doc("${_selectedCommunityName}_${_selectedYear}_$_selectedMonth");

      double parse(TextEditingController c) =>
          double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

      batch.set(reportRef, {
        'monthEnd': parse(_monthEndController),
        'others': parse(_othersController),
        'rent': parse(_rentController),
        'wine': parse(_wineController),
        'power': parse(_powerController),
        'sundries': parse(_sundriesController),
        'council': parse(_councilController),
        'equipment': parse(_equipmentController),
        'dateWeek1': _dateWeek1,
        'dateWeek2': _dateWeek2,
        'dateWeek3': _dateWeek3,
        'dateWeek4': _dateWeek4,
        'dateMonthEnd': _dateMonthEnd,
        'dateOthers': _dateOthers,
        'dateRent': _dateRent,
        'dateWine': _dateWine,
        'datePower': _datePower,
        'dateSundries': _dateSundries,
        'dateCouncil': _dateCouncil,
        'dateEquipment': _dateEquipment,
        'archivedAt': FieldValue.serverTimestamp(),
      });

      // D. Global Expenses Report
      final expenseReportRef = FirebaseFirestore.instance
          .collection('overseer_expenses_reports')
          .doc();
      double expOtherTotal =
          parse(_powerController) +
          parse(_sundriesController) +
          parse(_equipmentController);

      batch.set(expenseReportRef, {
        'overseerUid': uid,
        'districtElderName': _selectedDistrictElder,
        'communityName': _selectedCommunityName,
        'month': _selectedMonth,
        'year': _selectedYear,
        'province': _selectedProvince,
        'totalIncome': _totalIncome,
        'expenseRent': parse(_rentController),
        'expenseWine': parse(_wineController),
        'expenseCentral': parse(_councilController),
        'expenseOther': expOtherTotal,
        'totalExpenses': _totalExpenditure,
        'totalBanked': _creditBalance,
        'archivedAt': FieldValue.serverTimestamp(),
      });

      // E. Financial Summary
      final finReportRef = FirebaseFirestore.instance
          .collection('financial_report')
          .doc();
      batch.set(finReportRef, {
        'overseerUid': uid,
        'districtElderName': _selectedDistrictElder,
        'communityName': _selectedCommunityName,
        'month': _selectedMonth,
        'year': _selectedYear,
        'province': _selectedProvince,
        'totalIncome': _totalIncome,
        'totalExpenditure': _totalExpenditure,
        'creditBalance': _creditBalance,
        'archivedAt': FieldValue.serverTimestamp(),
      });

      OverseerAuditLogs.logAction(
        action: "ARCHIVED",
        details: "Archived report for $_selectedCommunityName",
        committeeMemberName: widget.committeeMemberName,
        committeeMemberRole: widget.committeeMemberRole,
        universityCommitteeFace: widget.faceUrl,
      );

      await batch.commit();

      // RELOAD DATA to reflect the new "Archived" status immediately
      await _fetchData();

      Navigator.pop(context); // Close Loading

      // AUTOMATICALLY OPEN PDF
      _openPdfPreviewScreen(pdfDataToGenerate);

      Api().showMessage(
        context,
        "Month Archived & PDF Generated.",
        "Success",
        Colors.green,
      );
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

  // --- Date Picker Helper ---
  Future<void> _pickDate(
    BuildContext context,
    Function(DateTime) onPicked,
  ) async {
    if (_isViewingHistory) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: EdgeInsets.all(widget.isLargeScreen ? 24 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Monthly Financial Report",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // --- 1. DROPDOWNS ---
              _buildTimeSelectors(),
              const SizedBox(height: 10),
              _buildOrgDropdowns(),

              if (_selectedCommunityName != null) ...[
                const Divider(height: 30),

                // --- 2. HISTORY INDICATOR ---
                if (_isViewingHistory)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: Colors.brown),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Status: ARCHIVED / CLOSED \nViewing Report: ${_getMonthName(_selectedMonth)} $_selectedYear",
                            style: const TextStyle(
                              color: Colors.brown,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- 3. INPUTS / DISPLAY ---
                _buildFinancialInputSection(),
                const SizedBox(height: 30),

                // --- 4. ACTION BUTTONS ---

                // CASE A: VIEWING ARCHIVED HISTORY (Based on DB status, not Calendar)
                if (_isViewingHistory) ...[
                  CustomOutlinedButton(
                    onPressed: () {
                      if (_selectedDistrictElder == null ||
                          _selectedCommunityName == null)
                        return;
                      // When viewing history, we pass the current state (which was loaded from DB)
                      final data = _buildCurrentPdfData();
                      _openPdfPreviewScreen(data);
                    },
                    text: "View Archived Balance Sheet (PDF)",
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    width: double.infinity,
                  ),
                ]
                // CASE B: LIVE MONTH EDITING
                else ...[
                  // Secondary Button: Preview Draft
                  CustomOutlinedButton(
                    onPressed: () {
                      if (_selectedDistrictElder == null ||
                          _selectedCommunityName == null)
                        return;
                      final data = _buildCurrentPdfData();
                      _openPdfPreviewScreen(data);
                    },
                    text: "Preview Draft (Does not Archive)",
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 15),

                  // Primary Button: Finalize & Archive
                  CustomOutlinedButton(
                    onPressed: _archiveAndGenerateReport,
                    text: "Finalize Month & Generate Report",
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Clicking this will Save to History, Reset Members, and Open the Balance Sheet PDF.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- UI WIDGETS (Unchanged) ---

  Widget _buildTimeSelectors() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DropdownButton<int>(
          value: _selectedMonth,
          items: List.generate(
            12,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text(_getMonthName(index + 1)),
            ),
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedMonth = val);
              _fetchData();
            }
          },
        ),
        const SizedBox(width: 20),
        DropdownButton<int>(
          value: _selectedYear,
          items: List.generate(
            10,
            (index) => DropdownMenuItem(
              value: 2024 + index,
              child: Text("${2024 + index}"),
            ),
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedYear = val);
              _fetchData();
            }
          },
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const m = [
      "",
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return m[month];
  }

  Widget _buildOrgDropdowns() {
    if (_overseerData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    List districts = _overseerData!['districts'] ?? [];
    List<String> elders = districts
        .map((e) => e['districtElderName'].toString())
        .toList();
    List<String> communities = [];
    if (_selectedDistrictElder != null) {
      var dist = districts.firstWhere(
        (e) => e['districtElderName'] == _selectedDistrictElder,
        orElse: () => null,
      );
      if (dist != null) {
        communities = (dist['communities'] as List)
            .map((c) => c['communityName'].toString())
            .toList();
      }
    }

    final elderDropdown = DropdownButtonFormField<String>(
      value: _selectedDistrictElder,
      hint: const Text("Select District Elder"),
      isExpanded: true,
      items: elders
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedDistrictElder = val;
          _selectedCommunityName = null;
        });
        _fetchData();
      },
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
    );

    final communityDropdown = DropdownButtonFormField<String>(
      value: _selectedCommunityName,
      hint: const Text("Select Community"),
      isExpanded: true,
      items: communities
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (val) {
        setState(() => _selectedCommunityName = val);
        if (val != null) _fetchData();
      },
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              elderDropdown,
              const SizedBox(height: 16),
              communityDropdown,
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(child: elderDropdown),
              const SizedBox(width: 16),
              Expanded(child: communityDropdown),
            ],
          );
        }
      },
    );
  }

  Widget _buildFinancialInputSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        if (isMobile) {
          return Column(
            children: [
              _buildIncomeCard(),
              const SizedBox(height: 20),
              _buildExpenditureCard(),
              const SizedBox(height: 20),
              _buildSummaryCard(),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildIncomeCard()),
                  const SizedBox(width: 20),
                  Expanded(child: _buildExpenditureCard()),
                ],
              ),
              const SizedBox(height: 20),
              _buildSummaryCard(),
            ],
          );
        }
      },
    );
  }

  Widget _buildIncomeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Income / Receipts",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),
            _incomeRow(
              "Week 1 (Auto)",
              _week1Sum,
              _dateWeek1,
              (d) => _dateWeek1 = d,
            ),
            _incomeRow(
              "Week 2 (Auto)",
              _week2Sum,
              _dateWeek2,
              (d) => _dateWeek2 = d,
            ),
            _incomeRow(
              "Week 3 (Auto)",
              _week3Sum,
              _dateWeek3,
              (d) => _dateWeek3 = d,
            ),
            _incomeRow(
              "Week 4 (Auto)",
              _week4Sum,
              _dateWeek4,
              (d) => _dateWeek4 = d,
            ),
            const Divider(),
            _inputRow(
              "Month End",
              _monthEndController,
              _dateMonthEnd,
              (d) => _dateMonthEnd = d,
            ),
            _inputRow(
              "Others",
              _othersController,
              _dateOthers,
              (d) => _dateOthers = d,
            ),
            const SizedBox(height: 10),
            _totalBlock("Total Income", _totalIncome, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenditureCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Expenditure",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),
            _inputRow(
              "Rent Period",
              _rentController,
              _dateRent,
              (d) => _dateRent = d,
            ),
            _inputRow(
              "Wine & Wafers",
              _wineController,
              _dateWine,
              (d) => _dateWine = d,
            ),
            _inputRow(
              "Power & Lights",
              _powerController,
              _datePower,
              (d) => _datePower = d,
            ),
            _inputRow(
              "Sundries",
              _sundriesController,
              _dateSundries,
              (d) => _dateSundries = d,
            ),
            _inputRow(
              "Central Council",
              _councilController,
              _dateCouncil,
              (d) => _dateCouncil = d,
            ),
            _inputRow(
              "Equipment",
              _equipmentController,
              _dateEquipment,
              (d) => _dateEquipment = d,
            ),
            const SizedBox(height: 10),
            _totalBlock("Total Expenditure", _totalExpenditure, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            "CREDIT BALANCE (Amount Banked):",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            "R ${_creditBalance.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalBlock(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: color.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            "R${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomeRow(
    String label,
    double value,
    DateTime? date,
    Function(DateTime) onDateSet,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                InkWell(
                  onTap: () => _pickDate(context, onDateSet),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date == null
                            ? "Select Date"
                            : "${date.year}-${date.month}-${date.day}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "R ${value.toStringAsFixed(2)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputRow(
    String label,
    TextEditingController controller,
    DateTime? date,
    Function(DateTime) onDateSet,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                InkWell(
                  onTap: () => _pickDate(context, onDateSet),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          date == null
                              ? "Set Date"
                              : "${date.year}-${date.month}-${date.day}",
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 35,
              child: TextField(
                controller: controller,
                readOnly: _isViewingHistory,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  prefixText: "R ",
                  prefixStyle: TextStyle(fontSize: 11, color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
