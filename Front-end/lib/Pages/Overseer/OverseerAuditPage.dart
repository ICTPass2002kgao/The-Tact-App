// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // Only for Auth UID
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ttact/Components/API.dart';

class OverseerAuditpage extends StatefulWidget {
  const OverseerAuditpage({super.key});

  @override
  State<OverseerAuditpage> createState() => _OverseerAuditpageState();
}

class _OverseerAuditpageState extends State<OverseerAuditpage> {
  // --- Color Palette ---
  final Color primaryBlue = const Color(0xFF1976D2);
  final Color successGreen = const Color(0xFF388E3C);
  final Color errorRed = const Color(0xFFD32F2F);
  final Color neutralGrey = const Color(0xFF757575);
  final Color lightBackground = const Color(0xFFF5F7FA);

  // --- STATE ---
  List<dynamic> _auditLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAuditLogs();
  }

  // --- 1. FETCH AUDIT LOGS (DJANGO) ---
  Future<void> _fetchAuditLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoading = true);

      // URL: /api/audit_logs/?uid=USER_UID
      // Assuming you have an endpoint that filters logs by the logged-in user's UID
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/audit_logs/?uid=${user.uid}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _auditLogs = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        print("Error fetching logs: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Network error: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- HELPER: Secure Image URL ---
  String _getSecureImageUrl(String originalUrl) {
    if (originalUrl.isEmpty || originalUrl == 'N/A') return "";
    return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(originalUrl)}';
  }

  Color _getActionColor(String action) {
    action = action.toUpperCase();
    if (action.contains('CREATE') ||
        action.contains('ADD') ||
        action.contains('UPDATE') ||
        action.contains('APPROVE')) {
      return successGreen;
    } else if (action.contains('DELETE') ||
        action.contains('REMOVE') ||
        action.contains('REJECT')) {
      return errorRed;
    } else if (action.contains('VIEW') ||
        action.contains('READ') ||
        action.contains('LOGGED')) {
      return primaryBlue;
    }
    return neutralGrey;
  }

  // --- IMAGE PREVIEW DIALOG ---
  void _showImagePreview(BuildContext context, String imageUrl, String title) {
    if (imageUrl.isEmpty || imageUrl == 'N/A') return;

    // Convert to secure proxy URL
    final secureUrl = _getSecureImageUrl(imageUrl);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(
                  secureUrl,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                  errorBuilder: (ctx, error, stack) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER TO GET TARGET STRING ---
  String _getTargetDisplay(Map<String, dynamic> d) {
    // Django keys are snake_case, map them safely
    final targetName = d['target_member_name'] ?? d['targetMemberName'];

    // 1. Check for Expense (Custom details parsing might be needed depending on how Django stores it)
    if (d['details'].toString().toLowerCase().contains('expense')) {
      return d['details']; // Return the details string for expenses
    }
    // 2. Check for Committee/Member
    if (targetName != null && targetName != 'N/A') {
      return targetName;
    }

    return d['details'] ?? '-';
  }

  // --- PDF GENERATION (UPDATED FOR JSON LIST) ---
  Future<void> _generateAndDownloadPdf() async {
    final pdf = pw.Document();

    // Use the already fetched list
    final data = _auditLogs;

    // Load App Logo for Header
    final logoImage = await rootBundle.load('assets/dankie_logo.PNG');
    final logoProvider = pw.MemoryImage(logoImage.buffer.asUint8List());

    final pdfPrimaryBlue = PdfColor.fromInt(primaryBlue.value);
    final pdfHeaderBg = PdfColor.fromInt(0xFFE3F2FD);

    List<List<dynamic>> pdfRows = [];

    for (var d in data) {
      // Date Parsing (Django returns ISO String)
      String dateStr = '-';
      if (d['timestamp'] != null) {
        try {
          DateTime dt = DateTime.parse(d['timestamp']);
          dateStr = DateFormat('yyyy-MM-dd HH:mm').format(dt);
        } catch (e) {
          dateStr = d['timestamp'].toString();
        }
      }

      // -- Face Logic --
      String faceUrl = d['actor_face_url'] ?? d['actorFaceUrl'] ?? 'N/A';
      pw.Widget faceWidget = pw.Text("-");

      // Note: PDF package can't easily download authenticated/proxied images
      // without extra work (downloading bytes first).
      // For simplicity in this migration, we display a placeholder or skip image in PDF
      // unless you implement byte downloading here.
      faceWidget = pw.Container(
        width: 20,
        height: 20,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          color: PdfColors.grey300,
        ),
      );

      String actorName = d['actor_name'] ?? d['actorName'] ?? 'Unknown';
      String actorRole = d['actor_role'] ?? d['actorRole'] ?? '';
      String displayActor = actorRole.isNotEmpty
          ? "$actorName\n($actorRole)"
          : actorName;

      String targetInfo = _getTargetDisplay(d);

      pdfRows.add([
        dateStr,
        faceWidget,
        displayActor,
        d['university_name'] ??
            d['universityName'] ??
            '-', // Assuming this mapped to Overseer Area
        d['action'] ?? '-',
        targetInfo,
        d['branch_email'] ?? d['branchEmail'] ?? '-',
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: pdfPrimaryBlue, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(logoProvider, width: 40, height: 40),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        'Overseer Audit Report',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfPrimaryBlue,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerDecoration: pw.BoxDecoration(color: pdfHeaderBg),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: pdfPrimaryBlue,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              headers: [
                'Time',
                'Face',
                'Actor',
                'Area',
                'Action',
                'Target / Details',
                'Email',
              ],
              data: pdfRows,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Audit_Log_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  void _showFullDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: primaryBlue),
            const SizedBox(width: 10),
            const Text("Full Audit Details"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: data.entries.map((e) {
              String valueStr = e.value.toString();

              // Hide explicit image URLs
              if (e.key.toLowerCase().contains('face') ||
                  e.key.toLowerCase().contains('url')) {
                return const SizedBox.shrink();
              }
              if (valueStr == 'N/A' || valueStr.isEmpty)
                return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: neutralGrey,
                      ),
                    ),
                    SelectableText(
                      valueStr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Divider(color: Colors.grey.shade200),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      backgroundImage: const AssetImage(
                        'assets/dankie_logo.PNG',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overseer Audit Logs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Track expenses, committee actions, and updates.',
                          style: TextStyle(fontSize: 14, color: neutralGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _generateAndDownloadPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text("Export PDF"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- TABLE ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: primaryBlue),
                      )
                    : _auditLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 40,
                              color: neutralGrey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "No logs found.",
                              style: TextStyle(color: neutralGrey),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              const Color(0xFFF8F9FC),
                            ),
                            headingRowHeight: 50,
                            dataRowMinHeight: 60,
                            dataRowMaxHeight: 70,
                            columnSpacing: 30,
                            horizontalMargin: 24,
                            columns: const [
                              DataColumn(label: Text('TIME')),
                              DataColumn(label: Text('FACE')),
                              DataColumn(label: Text('ACTOR')),
                              DataColumn(label: Text('OVERSEER AREA')),
                              DataColumn(label: Text('ACTION')),
                              DataColumn(label: Text('TARGET / DETAILS')),
                              DataColumn(label: Text('EMAIL')),
                              DataColumn(label: Text('DETAILS')),
                            ],
                            rows: _auditLogs.map((data) {
                              // Data Mapping (Django Snake Case support)
                              String timestampStr = data['timestamp'] ?? '';
                              String dateStr = '-';
                              if (timestampStr.isNotEmpty) {
                                try {
                                  DateTime dt = DateTime.parse(timestampStr);
                                  dateStr = DateFormat(
                                    'MMM dd, HH:mm',
                                  ).format(dt.toLocal());
                                } catch (e) {
                                  dateStr = timestampStr;
                                }
                              }

                              String actionStr = data['action'] ?? '';
                              Color actionColor = _getActionColor(actionStr);

                              String faceUrl =
                                  data['actor_face_url'] ??
                                  data['actorFaceUrl'] ??
                                  'N/A';
                              String secureFaceUrl = _getSecureImageUrl(
                                faceUrl,
                              );

                              String actorName =
                                  data['actor_name'] ??
                                  data['actorName'] ??
                                  'Unknown';
                              String actorRole =
                                  data['actor_role'] ?? data['actorRole'] ?? '';
                              String overseerName =
                                  data['university_name'] ??
                                  data['overseerName'] ??
                                  'N/A'; // Assuming legacy mapping
                              String targetDisplay = _getTargetDisplay(data);
                              String email =
                                  data['branch_email'] ??
                                  data['overseerEmail'] ??
                                  'System';

                              return DataRow(
                                cells: [
                                  // 1. Time
                                  DataCell(
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),

                                  // 2. Face
                                  DataCell(
                                    InkWell(
                                      onTap: () => _showImagePreview(
                                        context,
                                        faceUrl,
                                        "Actor Face",
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: primaryBlue.withOpacity(0.3),
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.grey.shade100,
                                          backgroundImage:
                                              (secureFaceUrl.isNotEmpty)
                                              ? NetworkImage(secureFaceUrl)
                                              : null,
                                          child: (secureFaceUrl.isEmpty)
                                              ? Icon(
                                                  Icons.person,
                                                  size: 16,
                                                  color: Colors.grey,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 3. Actor
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          actorName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (actorRole.isNotEmpty)
                                          Text(
                                            actorRole,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: neutralGrey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // 4. Area
                                  DataCell(
                                    Text(
                                      overseerName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  // 5. Action
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: actionColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: actionColor.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        actionStr,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: actionColor,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 6. Target
                                  DataCell(Text(targetDisplay)),

                                  // 7. Email
                                  DataCell(Text(email)),

                                  // 8. Details
                                  DataCell(
                                    IconButton(
                                      icon: Icon(
                                        Icons.visibility_outlined,
                                        color: primaryBlue,
                                      ),
                                      onPressed: () =>
                                          _showFullDetails(context, data),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
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
