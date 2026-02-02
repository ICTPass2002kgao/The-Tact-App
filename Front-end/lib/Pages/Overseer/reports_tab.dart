// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // Auth UID only
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Pages/Overseer/Services/pdf_generator_service.dart';
import 'package:ttact/Components/NeuDesign.dart';

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
  bool _isViewingHistory = false;

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

  // --- 1. Fetch Basic Info (Django) ---
  Future<void> _fetchOverseerDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final identifier = user.email ?? "";
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=$identifier',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          setState(() {
            _overseerData = results[0];
            _selectedProvince = _overseerData?['province'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching overseer: $e");
    }
  }

  // --- 2. Master Fetch Logic (Django) ---
  Future<void> _fetchData() async {
    if (_selectedDistrictElder == null || _selectedCommunityName == null) {
      return;
    }

    Api().showLoading(context);

    try {
      // Check if report exists for this month/year/community
      // URL: /api/monthly_reports/?community=X&month=Y&year=Z
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/monthly_reports/?community_name=$_selectedCommunityName&month=$_selectedMonth&year=$_selectedYear',
      );

      final response = await http.get(url);

      bool isArchived = false;
      Map<String, dynamic>? reportData;

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          isArchived = true;
          reportData = results[0];
        }
      }

      setState(() {
        _isViewingHistory = isArchived;
      });

      if (isArchived && reportData != null) {
        // Fetch Archived Data
        await _fetchHistoricalCommunityFinancials();
        _populateHistoricalReportSummary(reportData);
      } else {
        // Fetch Live Data
        await _fetchLiveCommunityFinancials();
        _clearFields();
      }

      _calculateTotals();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error fetching data: $e");
      Api().showMessage(context, "Error loading data", "Error", Colors.red);
    }
  }

  // --- 3. Fetch Live Financials (Django Users) ---
  Future<void> _fetchLiveCommunityFinancials() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // URL: /api/users/?overseer_uid=UID&district=D&community=C
    final url = Uri.parse(
      '${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=$uid&district_elder_name=$_selectedDistrictElder&community_name=$_selectedCommunityName',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return;

    final List users = json.decode(response.body);

    double w1 = 0, w2 = 0, w3 = 0, w4 = 0;
    for (var d in users) {
      w1 += double.tryParse(d['week1']?.toString() ?? '0') ?? 0.0;
      w2 += double.tryParse(d['week2']?.toString() ?? '0') ?? 0.0;
      w3 += double.tryParse(d['week3']?.toString() ?? '0') ?? 0.0;
      w4 += double.tryParse(d['week4']?.toString() ?? '0') ?? 0.0;
    }

    setState(() {
      _week1Sum = w1;
      _week2Sum = w2;
      _week3Sum = w3;
      _week4Sum = w4;
    });
  }

  // --- 4. Fetch Historical Financials (Django History) ---
  Future<void> _fetchHistoricalCommunityFinancials() async {
    // Assuming endpoint: /api/contribution_history/?community=C&month=M&year=Y
    final url = Uri.parse(
      '${Api().BACKEND_BASE_URL_DEBUG}/contribution_history/?community=$_selectedCommunityName&month=$_selectedMonth&year=$_selectedYear',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return;

    final List history = json.decode(response.body);

    double w1 = 0, w2 = 0, w3 = 0, w4 = 0;
    for (var d in history) {
      w1 += double.tryParse(d['week1']?.toString() ?? '0') ?? 0.0;
      w2 += double.tryParse(d['week2']?.toString() ?? '0') ?? 0.0;
      w3 += double.tryParse(d['week3']?.toString() ?? '0') ?? 0.0;
      w4 += double.tryParse(d['week4']?.toString() ?? '0') ?? 0.0;
    }

    setState(() {
      _week1Sum = w1;
      _week2Sum = w2;
      _week3Sum = w3;
      _week4Sum = w4;
    });
  }

  // --- 5. Populate History UI ---
  void _populateHistoricalReportSummary(Map<String, dynamic> d) {
    setState(() {
      _monthEndController.text = (d['month_end'] ?? 0.0).toString();
      _othersController.text = (d['others'] ?? 0.0).toString();
      _rentController.text = (d['rent'] ?? 0.0).toString();
      _wineController.text = (d['wine'] ?? 0.0).toString();
      _powerController.text = (d['power'] ?? 0.0).toString();
      _sundriesController.text = (d['sundries'] ?? 0.0).toString();
      _councilController.text = (d['council'] ?? 0.0).toString();
      _equipmentController.text = (d['equipment'] ?? 0.0).toString();

      DateTime? parseDate(dynamic val) {
        if (val == null) return null;
        try {
          return DateTime.parse(val);
        } catch (e) {
          return null;
        }
      }

      _dateWeek1 = parseDate(d['date_week1']);
      _dateWeek2 = parseDate(d['date_week2']);
      _dateWeek3 = parseDate(d['date_week3']);
      _dateWeek4 = parseDate(d['date_week4']);
      _dateMonthEnd = parseDate(d['date_month_end']);
      _dateOthers = parseDate(d['date_others']);
      _dateRent = parseDate(d['date_rent']);
      _dateWine = parseDate(d['date_wine']);
      _datePower = parseDate(d['date_power']);
      _dateSundries = parseDate(d['date_sundries']);
      _dateCouncil = parseDate(d['date_council']);
      _dateEquipment = parseDate(d['date_equipment']);
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

  ReportPdfData _buildCurrentPdfData() {
    String overseerName = "Overseer";
    if (_overseerData != null) {
      // Map fields (snake_case to CamelCase display)
      String n = _overseerData!['overseer_initials_surname'] ?? '';
      if (n.isNotEmpty) overseerName = n;
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

  // --- 6. ARCHIVE REPORT (DJANGO POST) ---
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

    final pdfDataToGenerate = _buildCurrentPdfData();

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

      // Prepare payload for Django Archive Endpoint
      final Map<String, dynamic> payload = {
        'overseer_uid': uid,
        'district_elder_name': _selectedDistrictElder,
        'community_name': _selectedCommunityName,
        'month': _selectedMonth,
        'year': _selectedYear,
        'province': _selectedProvince,
        // Amounts
        'month_end': double.tryParse(_monthEndController.text) ?? 0.0,
        'others': double.tryParse(_othersController.text) ?? 0.0,
        'rent': double.tryParse(_rentController.text) ?? 0.0,
        'wine': double.tryParse(_wineController.text) ?? 0.0,
        'power': double.tryParse(_powerController.text) ?? 0.0,
        'sundries': double.tryParse(_sundriesController.text) ?? 0.0,
        'council': double.tryParse(_councilController.text) ?? 0.0,
        'equipment': double.tryParse(_equipmentController.text) ?? 0.0,
        // Dates (ISO 8601 String)
        'date_week1': _dateWeek1?.toIso8601String(),
        'date_week2': _dateWeek2?.toIso8601String(),
        // ... (Send other dates similarly if needed by backend)
      };

      // POST to Custom Archive View in Django
      // URL: /api/monthly_reports/archive/
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/monthly_reports/archive/',
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Success
        OverseerAuditLogs.logAction(
          action: "ARCHIVED",
          details: "Archived report for $_selectedCommunityName",
          committeeMemberName: widget.committeeMemberName,
          committeeMemberRole: widget.committeeMemberRole,
          universityCommitteeFace: widget.faceUrl,
        );

        await _fetchData(); // Refresh local view
        if (mounted) Navigator.pop(context); // Close loading

        // Open PDF
        _openPdfPreviewScreen(pdfDataToGenerate);

        Api().showMessage(
          context,
          "Month Archived & PDF Generated.",
          "Success",
          Colors.green,
        );
      } else {
        print("Archive Failed: ${response.body}");
        if (mounted) Navigator.pop(context);
        Api().showMessage(
          context,
          "Archive failed: ${response.statusCode}",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        padding: EdgeInsets.all(widget.isLargeScreen ? 24 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Monthly Financial Report",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- 1. DROPDOWNS ---
            NeumorphicContainer(
              borderRadius: 16,
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTimeSelectors(),
                  const SizedBox(height: 16),
                  _buildOrgDropdowns(),
                ],
              ),
            ),

            if (_selectedCommunityName != null) ...[
              const SizedBox(height: 20),

              // --- 2. HISTORY INDICATOR ---
              if (_isViewingHistory)
                NeumorphicContainer(
                  isPressed: true,
                  borderRadius: 12,
                  padding: const EdgeInsets.all(12),
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

              if (_isViewingHistory) const SizedBox(height: 20),

              // --- 3. INPUTS / DISPLAY ---
              _buildFinancialInputSection(),
              const SizedBox(height: 30),

              // --- 4. ACTION BUTTONS ---
              if (_isViewingHistory) ...[
                _buildNeuButton(
                  onTap: () {
                    if (_selectedDistrictElder == null ||
                        _selectedCommunityName == null)
                      return;
                    final data = _buildCurrentPdfData();
                    _openPdfPreviewScreen(data);
                  },
                  label: "View Archived Balance Sheet (PDF)",
                  color: Colors.amber.shade800,
                  textColor: Colors.white,
                ),
              ] else ...[
                _buildNeuButton(
                  onTap: () {
                    if (_selectedDistrictElder == null ||
                        _selectedCommunityName == null)
                      return;
                    final data = _buildCurrentPdfData();
                    _openPdfPreviewScreen(data);
                  },
                  label: "Preview Draft (Does not Archive)",
                  color: Colors.grey.shade200,
                  textColor: Colors.black87,
                ),
                const SizedBox(height: 15),
                _buildNeuButton(
                  onTap: _archiveAndGenerateReport,
                  label: "Finalize Month & Generate Report",
                  color: Colors.red.shade700,
                  textColor: Colors.white,
                ),
                const SizedBox(height: 8),
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
    );
  }

  // ... (Widget Helpers remain largely the same, logic updated inside _buildOrgDropdowns) ...

  Widget _buildNeuButton({
    required VoidCallback onTap,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: NeumorphicContainer(
        isPressed: false,
        borderRadius: 12,
        padding: EdgeInsets.symmetric(vertical: 16),
        color: color == Colors.grey.shade200
            ? Theme.of(context).scaffoldBackgroundColor
            : color,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color == Colors.grey.shade200 ? Colors.black87 : textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelectors() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        NeumorphicContainer(
          isPressed: true,
          borderRadius: 8,
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedMonth,
              dropdownColor: theme.scaffoldBackgroundColor,
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
          ),
        ),
        const SizedBox(width: 20),
        NeumorphicContainer(
          isPressed: true,
          borderRadius: 8,
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              dropdownColor: theme.scaffoldBackgroundColor,
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
          ),
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
    final theme = Theme.of(context);
    if (_overseerData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Map Django keys
    List districts = _overseerData!['districts'] ?? [];
    List<String> elders = districts
        .map(
          (e) =>
              (e['district_elder_name'] ?? e['districtElderName']).toString(),
        )
        .toList();

    List<String> communities = [];
    if (_selectedDistrictElder != null) {
      var dist = districts.firstWhere(
        (e) =>
            (e['district_elder_name'] ?? e['districtElderName']) ==
            _selectedDistrictElder,
        orElse: () => null,
      );
      if (dist != null) {
        communities = (dist['communities'] as List)
            .map((c) => (c['community_name'] ?? c['communityName']).toString())
            .toList();
      }
    }

    final elderDropdown = NeumorphicContainer(
      isPressed: true,
      borderRadius: 12,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDistrictElder,
          hint: Text(
            "Select District Elder",
            style: TextStyle(color: theme.hintColor),
          ),
          isExpanded: true,
          dropdownColor: theme.scaffoldBackgroundColor,
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
        ),
      ),
    );

    final communityDropdown = NeumorphicContainer(
      isPressed: true,
      borderRadius: 12,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCommunityName,
          hint: Text(
            "Select Community",
            style: TextStyle(color: theme.hintColor),
          ),
          isExpanded: true,
          dropdownColor: theme.scaffoldBackgroundColor,
          items: communities
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) {
            setState(() => _selectedCommunityName = val);
            if (val != null) _fetchData();
          },
        ),
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
    return NeumorphicContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Income / Receipts",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green,
            ),
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
    );
  }

  Widget _buildExpenditureCard() {
    return NeumorphicContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Expenditure",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.red,
            ),
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
    );
  }

  Widget _buildSummaryCard() {
    return NeumorphicContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            "CREDIT BALANCE (Banked):",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          // Digital Display for Total
          NeumorphicContainer(
            isPressed: true,
            borderRadius: 8,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "R ${_creditBalance.toStringAsFixed(2)}",
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalBlock(String label, double value, Color color) {
    return NeumorphicContainer(
      isPressed: true,
      borderRadius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
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
                GestureDetector(
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
            child: NeumorphicContainer(
              isPressed: true,
              borderRadius: 8,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                "R ${value.toStringAsFixed(2)}",
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
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
                GestureDetector(
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
              height: 40,
              child: NeumorphicContainer(
                isPressed: true, // Sunken Input
                borderRadius: 8,
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: controller,
                  readOnly: _isViewingHistory,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    prefixText: "R ",
                    prefixStyle: TextStyle(fontSize: 11, color: Colors.grey),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.only(bottom: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
